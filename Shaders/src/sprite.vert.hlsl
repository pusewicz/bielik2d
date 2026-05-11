// Unified-vertex pass-through with SDF parameters forwarded to fragment.
// Sprite path uses pos + uv + color. SDF paths additionally use type, radius,
// stroke, aa, fill — all interpolated as constants across each quad since
// every vertex of the same quad carries identical SDF parameters.

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
    float  type     : TEXCOORD1;
    float  radius   : TEXCOORD2;
    float  stroke   : TEXCOORD3;
    float  aa       : TEXCOORD4;
    float  fill     : TEXCOORD5;
};

cbuffer CameraUBO : register(b0, space1) {
    float4x4 viewProj;
};

VSOutput main(VSInput input) {
    VSOutput o;
    o.position = mul(viewProj, float4(input.pos, 0.0, 1.0));
    o.uv = input.uv;
    o.color = float4(input.color.rgb, input.color.a * input.alpha);
    o.type = input.type;
    o.radius = input.radius;
    o.stroke = input.stroke;
    o.aa = input.aa;
    o.fill = input.fill;
    return o;
}
