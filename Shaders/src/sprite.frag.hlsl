struct PSInput {
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
    float4 color    : COLOR0;
};

Texture2D    mainTex     : register(t0, space2);
SamplerState mainSampler : register(s0, space2);

float4 main(PSInput input) : SV_Target {
    float4 tex = mainTex.Sample(mainSampler, input.uv);
    return tex * input.color;
}
