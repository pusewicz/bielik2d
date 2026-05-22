// Hand-written WGSL counterpart of sprite.vert.hlsl. Replaces the naga-emitted
// version because naga inserts a `position.y = -position.y` Y-flip for the
// Vulkan→WebGPU clip-space convention, which double-flips against our Camera
// projection (which already maps world Y-down to clip Y-up via -2/h scale).

struct CameraUBO {
    viewProj: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> camera: CameraUBO;

struct VertexInput {
    @location(0) pos: vec2<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) radius: f32,
    @location(4) stroke: f32,
    @location(5) aa: f32,
    @location(6) shape: f32,
    @location(7) alpha: f32,
    @location(8) fill: f32,
    @location(10) attributes: vec4<f32>,   // (texelW, texelH, scaleMode, _)
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) shape: f32,
    @location(3) radius: f32,
    @location(4) stroke: f32,
    @location(5) aa: f32,
    @location(6) fill: f32,
    @location(7) scaleData: vec4<f32>,
}

@vertex
fn main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = camera.viewProj * vec4<f32>(in.pos, 0.0, 1.0);
    out.uv = in.uv;
    out.color = vec4<f32>(in.color.rgb, in.color.a * in.alpha);
    out.shape = in.shape;
    out.radius = in.radius;
    out.stroke = in.stroke;
    out.aa = in.aa;
    out.fill = in.fill;
    out.scaleData = in.attributes;
    return out;
}
