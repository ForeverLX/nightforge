//! wgpu renderer for the S187 Phase 0 spike.
//!
//! Owns the wgpu instance/device/surface for the sctk layer surface plus
//! two minimal pipelines (shape + textured quad). Pipelines are built
//! lazily once the real surface format is known (first `resize`), and
//! rebuilt if the format changes. All colors are premultiplied to match
//! the chosen `CompositeAlphaMode::PreMultiplied`.

use std::ptr::NonNull;

use raw_window_handle::{
    RawDisplayHandle, RawWindowHandle, WaylandDisplayHandle, WaylandWindowHandle,
};
use wayland_client::protocol::wl_surface;
use wayland_client::{Connection, Proxy};

use crate::text::RasterText;

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct ShapeUniform {
    pub rect: [f32; 4],
    pub radius: f32,
    pub time: f32,
    pub _pad0: [f32; 2],
    pub color_a: [f32; 4],
    pub color_b: [f32; 4],
    pub size: [f32; 2],
    pub _pad1: [f32; 2],
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct TexUniform {
    pub rect: [f32; 4],
    pub size: [f32; 2],
    pub _pad: [f32; 2],
}

/// Result of acquiring a frame: ready to draw, or skip this cycle.
pub enum Frame {
    Ready {
        surface_texture: wgpu::SurfaceTexture,
        view: wgpu::TextureView,
        encoder: wgpu::CommandEncoder,
    },
    /// Timeout/occluded/etc. — draw nothing, retry next callback.
    Skip,
}

pub struct Renderer {
    pub surface: wgpu::Surface<'static>,
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    adapter: wgpu::Adapter,
    config: wgpu::SurfaceConfiguration,
    format: Option<wgpu::TextureFormat>,
    shape_bgl: wgpu::BindGroupLayout,
    tex_bgl: wgpu::BindGroupLayout,
    shape_pipeline: wgpu::RenderPipeline,
    tex_pipeline: wgpu::RenderPipeline,
    shape_bg: wgpu::BindGroup,
    shape_ubuf: wgpu::Buffer,
    tex_ubuf: wgpu::Buffer,
    sampler: wgpu::Sampler,
    /// Current surface size in px.
    pub size: (u32, u32),
}

impl Renderer {
    pub fn new(conn: &Connection, wl_surface: &wl_surface::WlSurface) -> Self {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::all(),
            ..wgpu::InstanceDescriptor::new_without_display_handle()
        });

        // sctk example pattern: raw Wayland handles → unsafe surface target.
        let raw_display_handle = RawDisplayHandle::Wayland(WaylandDisplayHandle::new(
            NonNull::new(conn.backend().display_ptr() as *mut _).unwrap(),
        ));
        let raw_window_handle = RawWindowHandle::Wayland(WaylandWindowHandle::new(
            NonNull::new(wl_surface.id().as_ptr() as *mut _).unwrap(),
        ));

        let surface = unsafe {
            instance
                .create_surface_unsafe(wgpu::SurfaceTargetUnsafe::RawHandle {
                    raw_display_handle: Some(raw_display_handle),
                    raw_window_handle,
                })
                .expect("failed to create wgpu surface")
        };

        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            compatible_surface: Some(&surface),
            ..Default::default()
        }))
        .expect("no suitable wgpu adapter");

        let (device, queue) = pollster::block_on(adapter.request_device(&Default::default()))
            .expect("failed to request device");

        // Shape bind group layout: one uniform buffer, no vertex buffer.
        let shape_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("shape-bgl"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });
        // Tex bind group layout: uniform + texture + sampler.
        let tex_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("tex-bgl"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
            ],
        });

        let shape_ubuf = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("shape-ubuf"),
            size: std::mem::size_of::<ShapeUniform>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let shape_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("shape-bg"),
            layout: &shape_bgl,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: shape_ubuf.as_entire_binding(),
            }],
        });
        let tex_ubuf = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("tex-ubuf"),
            size: std::mem::size_of::<TexUniform>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("linear"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        // Dummy pipelines; real ones are built on first resize() with the
        // actual surface format.
        let shape_pipeline = build_shape_pipeline(&device, &shape_bgl, wgpu::TextureFormat::Rgba8UnormSrgb);
        let tex_pipeline = build_tex_pipeline(&device, &tex_bgl, wgpu::TextureFormat::Rgba8UnormSrgb);

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: wgpu::TextureFormat::Rgba8UnormSrgb,
            view_formats: vec![],
            color_space: wgpu::SurfaceColorSpace::Auto,
            alpha_mode: wgpu::CompositeAlphaMode::PreMultiplied,
            width: 1,
            height: 1,
            desired_maximum_frame_latency: 2,
            present_mode: wgpu::PresentMode::Fifo,
        };

        Renderer {
            surface,
            device,
            queue,
            adapter,
            config,
            format: None,
            shape_bgl,
            tex_bgl,
            shape_pipeline,
            tex_pipeline,
            shape_bg,
            shape_ubuf,
            tex_ubuf,
            sampler,
            size: (1, 1),
        }
    }

    /// (Re)configure the surface for `width`×`height` px; rebuild pipelines
    /// when the surface format changes. Call on every layer-shell configure.
    pub fn resize(&mut self, width: u32, height: u32) {
        if width == 0 || height == 0 {
            return;
        }
        self.size = (width, height);
        let caps = self.surface.get_capabilities(&self.adapter);
        // Prefer a format with an alpha channel (translucent layer surface).
        let format = caps
            .formats
            .iter()
            .copied()
            .find(|f| has_alpha_channel(*f))
            .unwrap_or(caps.formats[0]);
        let alpha_mode = if caps.alpha_modes.contains(&wgpu::CompositeAlphaMode::PreMultiplied) {
            wgpu::CompositeAlphaMode::PreMultiplied
        } else {
            wgpu::CompositeAlphaMode::Auto
        };
        let present_mode = if caps.present_modes.contains(&wgpu::PresentMode::Mailbox) {
            wgpu::PresentMode::Mailbox
        } else {
            wgpu::PresentMode::Fifo
        };
        self.config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format,
            view_formats: vec![format],
            color_space: wgpu::SurfaceColorSpace::Auto,
            alpha_mode,
            width,
            height,
            desired_maximum_frame_latency: 2,
            present_mode,
        };
        self.surface.configure(&self.device, &self.config);

        if self.format != Some(format) {
            self.format = Some(format);
            self.shape_pipeline = build_shape_pipeline(&self.device, &self.shape_bgl, format);
            self.tex_pipeline = build_tex_pipeline(&self.device, &self.tex_bgl, format);
        }
        log::info!(
            "surface configured: {width}x{height} format={format:?} alpha={alpha_mode:?} present={present_mode:?}"
        );
    }

    /// Upload a premultiplied RGBA pixmap as a texture + bind group.
    pub fn upload_texture(&self, raster: &RasterText) -> (wgpu::Texture, wgpu::BindGroup) {
        let texture = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some("glyph-tex"),
            size: wgpu::Extent3d {
                width: raster.width,
                height: raster.height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba8UnormSrgb,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        self.queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            &raster.pixels,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(raster.width * 4),
                rows_per_image: Some(raster.height),
            },
            wgpu::Extent3d {
                width: raster.width,
                height: raster.height,
                depth_or_array_layers: 1,
            },
        );
        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
        let bind_group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("glyph-bg"),
            layout: &self.tex_bgl,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: self.tex_ubuf.as_entire_binding(),
                },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::TextureView(&view) },
                wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::Sampler(&self.sampler) },
            ],
        });
        (texture, bind_group)
    }

    /// Acquire the swapchain texture + command encoder for this frame.
    pub fn begin_frame(&mut self) -> Frame {
        match self.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(st)
            | wgpu::CurrentSurfaceTexture::Suboptimal(st) => {
                let view = st
                    .texture
                    .create_view(&wgpu::TextureViewDescriptor::default());
                let encoder = self
                    .device
                    .create_command_encoder(&wgpu::CommandEncoderDescriptor::default());
                Frame::Ready { surface_texture: st, view, encoder }
            }
            wgpu::CurrentSurfaceTexture::Outdated => {
                // Reconfigure and skip this frame.
                let (w, h) = self.size;
                self.resize(w, h);
                Frame::Skip
            }
            _ => Frame::Skip,
        }
    }

    pub fn clear(&self, encoder: &mut wgpu::CommandEncoder, view: &wgpu::TextureView, color: [f32; 4]) {
        // RenderPass ends on drop (wgpu 30); nothing else to do for a clear.
        let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("clear"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color {
                        r: color[0] as f64,
                        g: color[1] as f64,
                        b: color[2] as f64,
                        a: color[3] as f64,
                    }),
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
            multiview_mask: None,
        });
    }

    pub fn draw_shape(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        uniform: ShapeUniform,
    ) {
        self.queue.write_buffer(&self.shape_ubuf, 0, bytemuck::bytes_of(&uniform));
        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("shape"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
            multiview_mask: None,
        });
        pass.set_pipeline(&self.shape_pipeline);
        pass.set_bind_group(0, &self.shape_bg, &[]);
        pass.draw(0..6, 0..1);
    }

    pub fn draw_texture(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        bind_group: &wgpu::BindGroup,
        uniform: TexUniform,
    ) {
        self.queue.write_buffer(&self.tex_ubuf, 0, bytemuck::bytes_of(&uniform));
        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("tex"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
            multiview_mask: None,
        });
        pass.set_pipeline(&self.tex_pipeline);
        pass.set_bind_group(0, bind_group, &[]);
        pass.draw(0..6, 0..1);
    }

    pub fn present(&self, surface_texture: wgpu::SurfaceTexture, encoder: wgpu::CommandEncoder) {
        self.queue.submit(Some(encoder.finish()));
        self.queue.present(surface_texture);
    }
}

/// True for formats that carry an alpha channel (translucent layer surface).
fn has_alpha_channel(f: wgpu::TextureFormat) -> bool {
    matches!(
        f,
        wgpu::TextureFormat::Rgba8Unorm
            | wgpu::TextureFormat::Rgba8UnormSrgb
            | wgpu::TextureFormat::Bgra8Unorm
            | wgpu::TextureFormat::Bgra8UnormSrgb
            | wgpu::TextureFormat::Rgba16Float
            | wgpu::TextureFormat::Rgba32Float
            | wgpu::TextureFormat::Rgba16Unorm
            | wgpu::TextureFormat::Rgba32Uint
            | wgpu::TextureFormat::Rgba8Snorm
            | wgpu::TextureFormat::Rgba16Snorm
            | wgpu::TextureFormat::Rgba16Uint
            | wgpu::TextureFormat::Rgba8Uint
            | wgpu::TextureFormat::Rgba32Sint
            | wgpu::TextureFormat::Rgba16Sint
            | wgpu::TextureFormat::Rgba8Sint
    )
}

fn build_shape_pipeline(    device: &wgpu::Device,
    bgl: &wgpu::BindGroupLayout,
    format: wgpu::TextureFormat,
) -> wgpu::RenderPipeline {
    let pl = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("shape-pl"),
        bind_group_layouts: &[Some(bgl)],
        immediate_size: 0,
    });
    let module = device.create_shader_module(wgpu::include_wgsl!("shape.wgsl"));
    device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some("shape"),
        layout: Some(&pl),
        vertex: wgpu::VertexState {
            module: &module,
            entry_point: Some("vs_shape"),
            compilation_options: Default::default(),
            buffers: &[],
        },
        primitive: wgpu::PrimitiveState::default(),
        depth_stencil: None,
        multisample: wgpu::MultisampleState::default(),
        fragment: Some(wgpu::FragmentState {
            module: &module,
            entry_point: Some("fs_shape"),
            compilation_options: Default::default(),
            targets: &[Some(wgpu::ColorTargetState {
                format,
                blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING),
                write_mask: wgpu::ColorWrites::ALL,
            })],
        }),
        multiview_mask: None,
        cache: None,
    })
}

fn build_tex_pipeline(
    device: &wgpu::Device,
    bgl: &wgpu::BindGroupLayout,
    format: wgpu::TextureFormat,
) -> wgpu::RenderPipeline {
    let pl = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("tex-pl"),
        bind_group_layouts: &[Some(bgl)],
        immediate_size: 0,
    });
    let module = device.create_shader_module(wgpu::include_wgsl!("texture.wgsl"));
    device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some("tex"),
        layout: Some(&pl),
        vertex: wgpu::VertexState {
            module: &module,
            entry_point: Some("vs_tex"),
            compilation_options: Default::default(),
            buffers: &[],
        },
        primitive: wgpu::PrimitiveState::default(),
        depth_stencil: None,
        multisample: wgpu::MultisampleState::default(),
        fragment: Some(wgpu::FragmentState {
            module: &module,
            entry_point: Some("fs_tex"),
            compilation_options: Default::default(),
            targets: &[Some(wgpu::ColorTargetState {
                format,
                blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING),
                write_mask: wgpu::ColorWrites::ALL,
            })],
        }),
        multiview_mask: None,
        cache: None,
    })
}

impl std::fmt::Debug for Renderer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Renderer")
            .field("size", &self.size)
            .field("format", &self.format)
            .finish_non_exhaustive()
    }
}
