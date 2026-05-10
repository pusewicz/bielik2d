struct VSInput {
    float2 position : POSITION;
    float4 color    : COLOR0;
};

struct VSOutput {
    float4 position : SV_Position;
    float4 color    : COLOR0;
};

VSOutput main(VSInput input) {
    VSOutput o;
    o.position = float4(input.position, 0.0, 1.0);
    o.color = input.color;
    return o;
}
