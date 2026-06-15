// Hand-written WGSL counterpart of sprite.frag.hlsl. naga can't transpile
// the HLSL because shadercross's register(t0, space2) / register(s0, space2)
// convention puts texture and sampler at the same WGSL binding index, which
// WebGPU forbids. We split them into distinct bindings here while keeping
// behaviour identical to the HLSL source.
//
// type branches:
//   0 -> sprite
//   1 -> circle SDF
//   2 -> line SDF
//   3 -> box SDF (scaleData.xy = halfW, halfH)

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
    @location(8) uvBounds: vec4<f32>,    // atlas sub-rect (minU,minV,maxU,maxV); zero = none
}

@group(1) @binding(0) var mainTex: texture_2d<f32>;
@group(1) @binding(1) var mainSampler: sampler;

// Signed distance to a rounded rectangle centred at origin with half-extents b and corner radius r.
fn sdRoundBox(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let d = abs(p) - b + r;
    return length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

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
        let bounds = in.uvBounds;                       // atlas sub-rect, or zero
        let atlased = (bounds.z > bounds.x) && (bounds.w > bounds.y);
        let origin = select(vec2<f32>(0.0), bounds.xy, atlased);
        let extent = select(vec2<f32>(1.0), bounds.zw - bounds.xy, atlased);
        var uv = in.uv;
        // Snap in the sprite's own [0,1] space (matching a standalone texture),
        // then map back into the atlas sub-rect.
        if ((mode == 1 || mode == 2) && texSize.x > 0.0) {
            let local = (uv - origin) / extent;
            let localDdx = uvDdx / extent;
            let localDdy = uvDdy / extent;
            var snapped: vec2<f32>;
            if (mode == 1) {
                snapped = getPixelArtUV(local, texSize, localDdx, localDdy);
            } else {
                snapped = (floor(local * texSize) + 0.5) / texSize;   // nearest
            }
            uv = origin + snapped * extent;
        }
        // Keep sampling inside the sub-rect: clamp to a half-texel inset so linear
        // taps never cross into a neighbouring sprite on the same page.
        if (atlased) {
            let half_texel = 0.5 * extent / texSize;
            uv = clamp(uv, bounds.xy + half_texel, bounds.zw - half_texel);
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
        // Line: box SDF for square end caps with AA on all four edges.
        // uv is in line-centred world coords: x along the segment, y perpendicular.
        // scaleData.x = halfLen (half the segment length in world units).
        let halfLen = in.scaleData.x;
        let dist = sdRoundBox(in.uv, vec2<f32>(halfLen, in.stroke * 0.5), 0.0);
        let a = smoothstep(in.aa, -in.aa, dist);
        return vec4<f32>(in.color.rgb, in.color.a * a);
    }
    if (t == 3) {
        // scaleData.xy = (halfW, halfH) passed via Vertex.attributes
        let halfExtents = in.scaleData.xy;
        let dist = sdRoundBox(in.uv, halfExtents, in.radius);
        var a: f32;
        if (in.fill > 0.5) {
            a = smoothstep(in.aa, -in.aa, dist);
        } else {
            let halfStroke = in.stroke * 0.5;
            a = smoothstep(halfStroke + in.aa, halfStroke - in.aa, abs(dist));
        }
        return vec4<f32>(in.color.rgb, in.color.a * a);
    }
    return in.color;
}
