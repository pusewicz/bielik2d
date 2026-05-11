// Branches on input.type:
//   0 -> sprite: sample texture * color
//   1 -> circle fill: SDF disk in uv space, radius in local-extent units
//   2 -> line: uv.y is signed-distance across the segment, [-1..+1]
//   3 -> box: reserved
// SDF anti-aliasing uses a soft edge of width `aa` (in the same units as uv).

struct PSInput {
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
    float4 color    : COLOR0;
    float  type     : TEXCOORD1;
    float  radius   : TEXCOORD2;
    float  stroke   : TEXCOORD3;
    float  aa       : TEXCOORD4;
    float  fill     : TEXCOORD5;
};

Texture2D    mainTex     : register(t0, space2);
SamplerState mainSampler : register(s0, space2);

float4 main(PSInput input) : SV_Target {
    int t = (int)round(input.type);
    if (t == 0) {
        float4 tex = mainTex.Sample(mainSampler, input.uv);
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
