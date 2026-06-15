// Branches on input.type:
//   0 -> sprite: sample texture * color
//   1 -> circle fill: SDF disk, uv is box-local position, radius is circle radius
//   2 -> line: uv.y is signed-distance across the segment, [-1..+1]
//   3 -> box: SDF rounded rect; uv is box-local position, scaleData.xy = (halfW, halfH)
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
    float4 uvBounds  : TEXCOORD7;   // atlas sub-rect (minU,minV,maxU,maxV); zero = none
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

// Signed distance to a rounded rectangle centred at the origin with half-extents
// `b` and corner radius `r`. Negative inside, zero on the boundary, positive outside.
float sdRoundBox(float2 p, float2 b, float r) {
    float2 d = abs(p) - b + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
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
        float4 bounds = input.uvBounds;                  // atlas sub-rect, or zero
        bool atlased = (bounds.z > bounds.x) && (bounds.w > bounds.y);
        float2 origin = atlased ? bounds.xy : float2(0.0, 0.0);
        float2 extent = atlased ? (bounds.zw - bounds.xy) : float2(1.0, 1.0);
        float2 uv = input.uv;
        // Snap in the sprite's own [0,1] space (matching a standalone texture),
        // then map back into the atlas sub-rect.
        if ((mode == 1 || mode == 2) && texSize.x > 0.0) {
            float2 local = (uv - origin) / extent;
            float2 localDdx = uvDdx / extent;
            float2 localDdy = uvDdy / extent;
            float2 snapped = (mode == 1)
                ? GetPixelArtUV(local, texSize, localDdx, localDdy)
                : (floor(local * texSize) + 0.5) / texSize;       // nearest
            uv = origin + snapped * extent;
        }
        // Keep sampling inside the sub-rect: clamp to a half-texel inset so linear
        // taps never cross into a neighbouring sprite on the same page.
        if (atlased) {
            float2 halfTexel = 0.5 * extent / texSize;
            uv = clamp(uv, bounds.xy + halfTexel, bounds.zw - halfTexel);
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
    if (t == 3) {
        // box: scaleData.xy carries (halfW, halfH) passed via Vertex.attributes.
        float2 halfExtents = input.scaleData.xy;
        float dist = sdRoundBox(input.uv, halfExtents, input.radius);
        float a;
        if (input.fill > 0.5) {
            // filled: opaque inside, AA at outer edge
            a = smoothstep(input.aa, -input.aa, dist);
        } else {
            // stroked: opaque at |dist| < stroke/2, AA on both inner and outer edges
            a = smoothstep(input.stroke * 0.5 + input.aa,
                           input.stroke * 0.5 - input.aa, abs(dist));
        }
        return float4(input.color.rgb, input.color.a * a);
    }
    // unknown type -> render solid color for visibility
    return input.color;
}
