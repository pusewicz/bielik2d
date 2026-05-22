// Branches on input.type:
//   0 -> sprite: sample texture * color
//   1 -> circle fill: SDF disk in uv space, radius in local-extent units
//   2 -> line: uv.y is signed-distance across the segment, [-1..+1]
//   3 -> box: reserved
// SDF anti-aliasing uses a soft edge of width `aa` (in the same units as uv).

struct PSInput {
    float4 position  : SV_Position;
    float2 uv        : TEXCOORD0;
    float4 color     : COLOR0;
    float  type      : TEXCOORD1;
    float  radius    : TEXCOORD2;
    float  stroke    : TEXCOORD3;
    float  aa        : TEXCOORD4;
    float  fill      : TEXCOORD5;
    float4 scaleData : TEXCOORD6;   // (texelW, texelH, scaleMode, _)
};

Texture2D    mainTex     : register(t0, space2);
SamplerState mainSampler : register(s0, space2);

// SDL_SCALEMODE_PIXELART: antialiased pixel-art upscaling. With a LINEAR
// sampler, nudge the sampled coordinate so each source texel reads flat across
// its interior and the linear blend only happens in the ~1px screen-space seam
// between texels — crisp like nearest, but shimmer-free at non-integer scale.
// `texSize` is the source texture size in texels. Mirrors SDL's GetPixelArtUV.
float2 GetPixelArtUV(float2 uv, float2 texSize, float2 uvDdx, float2 uvDdy) {
    float2 boxSize = clamp((abs(uvDdx) + abs(uvDdy)) * texSize, 1e-5, 1.0);
    float2 tx = uv * texSize - 0.5 * boxSize;
    float2 txOffset = smoothstep(1.0 - boxSize, float2(1.0, 1.0), frac(tx));
    return (floor(tx) + 0.5 + txOffset) / texSize;
}

float4 main(PSInput input) : SV_Target {
    int t = (int)round(input.type);
    // Derivatives are evaluated up front (uniform control flow) so the pixel-art
    // path matches the WGSL backend, which forbids them inside the type branch.
    float2 uvDdx = ddx(input.uv);
    float2 uvDdy = ddy(input.uv);
    if (t == 0) {
        float2 texSize = input.scaleData.xy;
        int mode = (int)round(input.scaleData.z);
        float2 uv = input.uv;
        if (mode == 1 && texSize.x > 0.0) {
            uv = GetPixelArtUV(input.uv, texSize, uvDdx, uvDdy);   // pixel art
        } else if (mode == 2 && texSize.x > 0.0) {
            uv = (floor(input.uv * texSize) + 0.5) / texSize;      // nearest
        }
        float4 tex = mainTex.SampleGrad(mainSampler, uv, uvDdx, uvDdy);
        return tex * input.color;
    }
    if (t == 1) {
        // circle: distance from uv origin in local-extent units
        float d = length(input.uv);
        float a = smoothstep(input.radius + input.aa, input.radius - input.aa, d);
        return float4(input.color.rgb, input.color.a * a);
    }
    if (t == 2) {
        // line: uv.y carries signed perpendicular distance in half-thickness+aa units
        // half_thickness in same units = stroke/2 + aa, normalized to 1 at edge of aa band
        float halfBand = (input.stroke * 0.5 + input.aa);
        float d = abs(input.uv.y) * halfBand;       // 0 at centerline, halfBand at outer edge
        float core = input.stroke * 0.5;
        float a = smoothstep(core + input.aa, core - input.aa, d);
        return float4(input.color.rgb, input.color.a * a);
    }
    // unknown type -> render solid color for visibility
    return input.color;
}
