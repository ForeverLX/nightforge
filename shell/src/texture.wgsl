// S187 Phase 0 spike — textured-quad pipeline (glyph textures).

struct TexUniform {
    rect: vec4<f32>,   // x, y, w, h (surface px, y down)
    size: vec2<f32>,   // surface size for NDC
    _pad: vec2<f32>,
}

@group(0) @binding(0) var<uniform> u: TexUniform;
@group(0) @binding(1) var tex: texture_2d<f32>;
@group(0) @binding(2) var samp: sampler;

struct VsOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

const CORNERS: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
    vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 0.0), vec2<f32>(0.0, 1.0),
    vec2<f32>(1.0, 0.0), vec2<f32>(1.0, 1.0), vec2<f32>(0.0, 1.0),
);

@vertex
fn vs_tex(@builtin(vertex_index) vi: u32) -> VsOut {
    var out: VsOut;
    let c = CORNERS[vi];
    let pos_px = u.rect.xy + c * u.rect.zw;
    let ndc = vec2<f32>(
        pos_px.x / u.size.x * 2.0 - 1.0,
        1.0 - pos_px.y / u.size.y * 2.0,
    );
    out.pos = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = c;
    return out;
}

@fragment
fn fs_tex(in: VsOut) -> @location(0) vec4<f32> {
    // Texture is premultiplied on upload; blend as-is.
    return textureSample(tex, samp, in.uv);
}
