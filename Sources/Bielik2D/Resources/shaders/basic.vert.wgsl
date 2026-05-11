struct VertexOutput {
    @builtin(position) member: vec4<f32>,
    @location(0) member_1: vec4<f32>,
}

var<private> input_u002e_position_1: vec2<f32>;
var<private> input_u002e_color_1: vec4<f32>;
var<private> u0040_entryPointOutput_u002e_position: vec4<f32> = vec4<f32>(0f, 0f, 0f, 1f);
var<private> u0040_entryPointOutput_u002e_color: vec4<f32>;

fn main_1() {
    let _e6 = input_u002e_position_1;
    let _e7 = input_u002e_color_1;
    u0040_entryPointOutput_u002e_position = vec4<f32>(_e6.x, _e6.y, 0f, 1f);
    u0040_entryPointOutput_u002e_color = _e7;
    return;
}

@vertex 
fn main(@location(0) input_u002e_position: vec2<f32>, @location(1) input_u002e_color: vec4<f32>) -> VertexOutput {
    input_u002e_position_1 = input_u002e_position;
    input_u002e_color_1 = input_u002e_color;
    main_1();
    let _e7 = u0040_entryPointOutput_u002e_position.y;
    u0040_entryPointOutput_u002e_position.y = -(_e7);
    let _e9 = u0040_entryPointOutput_u002e_position;
    let _e10 = u0040_entryPointOutput_u002e_color;
    return VertexOutput(_e9, _e10);
}
