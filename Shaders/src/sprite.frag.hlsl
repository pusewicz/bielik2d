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

// Signed distance to the triangle (a, b, c). Negative inside. (Inigo Quilez.)
float sdTriangle(float2 p, float2 a, float2 b, float2 c) {
    float2 e0 = b - a, e1 = c - b, e2 = a - c;
    float2 v0 = p - a, v1 = p - b, v2 = p - c;
    float2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    float2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    float2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    float2 d = min(min(float2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                       float2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                       float2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
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
        // circle: distance from uv origin in local-extent units.
        float d = length(input.uv);
        float a;
        if (input.fill > 0.5) {
            // filled disk: opaque inside, AA at the outer edge
            a = smoothstep(input.radius + input.aa, input.radius - input.aa, d);
        } else {
            // outline: opaque band of `stroke` width centred on the radius
            a = smoothstep(input.stroke * 0.5 + input.aa,
                           input.stroke * 0.5 - input.aa, abs(d - input.radius));
        }
        return float4(input.color.rgb, input.color.a * a);
    }
    if (t == 2) {
        // Line: box SDF for square end caps with AA on all four edges.
        // uv is in line-centred world coords: x along the segment, y perpendicular.
        // scaleData.x = halfLen (half the segment length in world units).
        float halfLen = input.scaleData.x;
        float dist = sdRoundBox(input.uv, float2(halfLen, input.stroke * 0.5), 0.0);
        float a = smoothstep(input.aa, -input.aa, dist);
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
    if (t == 4) {
        // Capsule: segment along local x in [-halfLen, halfLen], rounded by `radius`.
        // uv is in capsule-local world coords; scaleData.x = halfLen.
        float halfLen = input.scaleData.x;
        float dx = abs(input.uv.x) - halfLen;
        float dist = length(float2(max(dx, 0.0), input.uv.y)) - input.radius;
        float a;
        if (input.fill > 0.5) {
            a = smoothstep(input.aa, -input.aa, dist);
        } else {
            a = smoothstep(input.stroke * 0.5 + input.aa,
                           input.stroke * 0.5 - input.aa, abs(dist));
        }
        return float4(input.color.rgb, input.color.a * a);
    }
    if (t == 5) {
        // triangle: corners packed scaleData.xy = a, scaleData.zw = b, uvBounds.xy = c.
        float2 a = input.scaleData.xy;
        float2 b = input.scaleData.zw;
        float2 c = input.uvBounds.xy;
        float dist = sdTriangle(input.uv, a, b, c);
        float al = smoothstep(input.aa, -input.aa, dist);
        return float4(input.color.rgb, input.color.a * al);
    }
    if (t == 6) {
        // convex polygon fill: one centroid-fan triangle per edge. scaleData.xy/zw
        // carry the triangle's true outer edge (A, B) in centroid-local coords; uv
        // is the fragment's centroid-local position. We antialias only that edge —
        // distance to its half-plane, oriented so the centroid (origin) is inside —
        // so the interior spokes shared between fan triangles get no fringe.
        float2 ea = input.scaleData.xy;
        float2 eb = input.scaleData.zw;
        float2 nrm = normalize(float2((eb - ea).y, -(eb - ea).x));
        if (dot(-ea, nrm) > 0.0) nrm = -nrm;   // make the origin side negative (inside)
        float dist = dot(input.uv - ea, nrm);
        float a = smoothstep(input.aa, -input.aa, dist);
        return float4(input.color.rgb, input.color.a * a);
    }
    // unknown type -> render solid color for visibility
    return input.color;
}
