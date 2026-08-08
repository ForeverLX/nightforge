// S187 Phase 0 spike — shape pipeline.
// One unit quad expanded from `@builtin(vertex_index)` (no vertex buffer),
// rect in surface pixels (y-down), SDF-rounded corners, vertical gradient.

struct ShapeUniform {
    rect: vec4<f32>,   // x, y, w, h (surface px, y down)
    radius: f32,
    time: f32,
    _pad0: vec2<f32>,
    color_a: vec4<f32>, // premultiplied
    color_b: vec4<f32>, // premultiplied
    size: vec2<f32>,    // surface size for NDC
    _pad1: vec2<f32>,
}

@group(0) @binding(0) var<uniform> u: ShapeUniform;

struct VsOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) local: vec2<f32>,
}

const CORNERS: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
    vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 0.0), vec2<f32>(0.0, 1.0),
    vec2<f32>(1.0, 0.0), vec2<f32>(1.0, 1.0), vec2<f32>(0.0, 1.0),
);

@vertex
fn vs_shape(@builtin(vertex_index) vi: u32) -> VsOut {
    var out: VsOut;
    let c = CORNERS[vi];
    let pos_px = u.rect.xy + c * u.rect.zw;
    let ndc = vec2<f32>(
        pos_px.x / u.size.x * 2.0 - 1.0,
        1.0 - pos_px.y / u.size.y * 2.0,
    );
    out.pos = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = c;
    out.local = pos_px;
    return out;
}

fn sd_rounded_rect(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let q = abs(p) - b + vec2<f32>(r);
    return length(max(q, vec2<f32>(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

@fragment
fn fs_shape(in: VsOut) -> @location(0) vec4<f32> {
    let half = u.rect.zw * 0.5;
    let center = u.rect.xy + half;
    let r = max(u.radius, 0.0);
    let d = sd_rounded_rect(in.local - center, half - vec2<f32>(r), r);
    let alpha = 1.0 - smoothstep(-1.0, 1.0, d);
    let grad = mix(u.color_a, u.color_b, in.uv.y);
    return vec4<f32>(grad.rgb, grad.a * alpha);
}
