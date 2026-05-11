// Hand-written WGSL counterpart of sprite.frag.hlsl. naga can't transpile
// the HLSL because shadercross's register(t0, space2) / register(s0, space2)
// convention puts texture and sampler at the same WGSL binding index, which
// WebGPU forbids. We split them into distinct bindings here while keeping
// behaviour identical to the HLSL source.

struct FragInput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) type: f32,
    @location(3) radius: f32,
    @location(4) stroke: f32,
    @location(5) aa: f32,
    @location(6) fill: f32,
}

@group(2) @binding(0) var mainTex: texture_2d<f32>;
@group(2) @binding(1) var mainSampler: sampler;

@fragment
fn main(in: FragInput) -> @location(0) vec4<f32> {
    let t = i32(round(in.type));
    if (t == 0) {
        let tex = textureSample(mainTex, mainSampler, in.uv);
        return tex * in.color;
    }
    if (t == 1) {
        let d = length(in.uv);
        let a = smoothstep(in.radius + in.aa, in.radius - in.aa, d);
        return vec4<f32>(in.color.rgb, in.color.a * a);
    }
    if (t == 2) {
        let half_band = in.stroke * 0.5 + in.aa;
        let d = abs(in.uv.y) * half_band;
        let core = in.stroke * 0.5;
        let a = smoothstep(core + in.aa, core - in.aa, d);
        return vec4<f32>(in.color.rgb, in.color.a * a);
    }
    return in.color;
}
