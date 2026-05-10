// Unified-vertex pass-through. Reads the full CF-style vertex but for v0
// only the pos, uv, color, alpha fields actually feed the fragment stage.
// The remaining fields (radius, stroke, aa, type, fill, posH, attributes,
// uvBounds) are still consumed as inputs so the vertex layout stays stable
// for Phase 8 (SDF shapes).

struct VSInput {
    float2 pos        : POSITION0;
    float2 uv         : TEXCOORD0;
    float4 color      : COLOR0;
    float  radius     : TEXCOORD1;
    float  stroke     : TEXCOORD2;
    float  aa         : TEXCOORD3;
    float  type       : TEXCOORD4;
    float  alpha      : TEXCOORD5;
    float  fill       : TEXCOORD6;
    float2 posH       : TEXCOORD7;
    float4 attributes : COLOR1;
    float4 uvBounds   : TEXCOORD8;
};

struct VSOutput {
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
    float4 color    : COLOR0;
};

VSOutput main(VSInput input) {
    VSOutput o;
    o.position = float4(input.pos, 0.0, 1.0);
    o.uv = input.uv;
    o.color = float4(input.color.rgb, input.color.a * input.alpha);
    return o;
}
