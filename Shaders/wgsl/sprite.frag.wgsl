// Hand-written WGSL counterpart of sprite.frag.hlsl. naga can't transpile
// the HLSL because shadercross's register(t0, space2) / register(s0, space2)
// convention puts texture and sampler at the same WGSL binding index, which
// WebGPU forbids. We split them into distinct bindings here while keeping
// behaviour identical to the HLSL source.

struct FragInput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) shape: f32,
    @location(3) radius: f32,
    @location(4) stroke: f32,
    @location(5) aa: f32,
    @location(6) fill: f32,
    @location(7) scaleData: vec4<f32>,   // (texelW, texelH, scaleMode, _)
}

@group(1) @binding(0) var mainTex: texture_2d<f32>;
@group(1) @binding(1) var mainSampler: sampler;

// SDL_SCALEMODE_PIXELART, matching sprite.frag.hlsl GetPixelArtUV.
fn getPixelArtUV(uv: vec2<f32>, texSize: vec2<f32>, uvDdx: vec2<f32>, uvDdy: vec2<f32>) -> vec2<f32> {
    let boxSize = clamp((abs(uvDdx) + abs(uvDdy)) * texSize, vec2<f32>(1e-5), vec2<f32>(1.0));
    let tx = uv * texSize - 0.5 * boxSize;
    let txOffset = smoothstep(vec2<f32>(1.0) - boxSize, vec2<f32>(1.0), fract(tx));
    return (floor(tx) + 0.5 + txOffset) / texSize;
}

@fragment
fn main(in: FragInput) -> @location(0) vec4<f32> {
    let t = i32(round(in.shape));
    // Derivatives must be taken in uniform control flow, so compute them before
    // the (non-uniform) shape branch; textureSampleGrad with explicit gradients
    // is then allowed inside the branch.
    let uvDdx = dpdx(in.uv);
    let uvDdy = dpdy(in.uv);
    if (t == 0) {
        let texSize = in.scaleData.xy;
        let mode = i32(round(in.scaleData.z));
        var uv = in.uv;
        if (mode == 1 && texSize.x > 0.0) {
            uv = getPixelArtUV(in.uv, texSize, uvDdx, uvDdy);     // pixel art
        } else if (mode == 2 && texSize.x > 0.0) {
            uv = (floor(in.uv * texSize) + 0.5) / texSize;        // nearest
        }
        let tex = textureSampleGrad(mainTex, mainSampler, uv, uvDdx, uvDdy);
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
