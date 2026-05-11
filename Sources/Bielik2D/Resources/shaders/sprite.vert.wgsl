struct CameraUBO {
    viewProj: mat4x4<f32>,
}

struct VertexOutput {
    @builtin(position) member: vec4<f32>,
    @location(0) member_1: vec2<f32>,
    @location(1) member_2: vec4<f32>,
    @location(2) member_3: f32,
    @location(3) member_4: f32,
    @location(4) member_5: f32,
    @location(5) member_6: f32,
    @location(6) member_7: f32,
}

@group(1) @binding(0) 
var<uniform> unnamed: CameraUBO;
var<private> input_u002e_pos_1: vec2<f32>;
var<private> input_u002e_uv_1: vec2<f32>;
var<private> input_u002e_color_1: vec4<f32>;
var<private> input_u002e_radius_1: f32;
var<private> input_u002e_stroke_1: f32;
var<private> input_u002e_aa_1: f32;
var<private> input_u002e_type_1: f32;
var<private> input_u002e_alpha_1: f32;
var<private> input_u002e_fill_1: f32;
var<private> u0040_entryPointOutput_u002e_position: vec4<f32> = vec4<f32>(0f, 0f, 0f, 1f);
var<private> u0040_entryPointOutput_u002e_uv: vec2<f32>;
var<private> u0040_entryPointOutput_u002e_color: vec4<f32>;
var<private> u0040_entryPointOutput_u002e_type: f32;
var<private> u0040_entryPointOutput_u002e_radius: f32;
var<private> u0040_entryPointOutput_u002e_stroke: f32;
var<private> u0040_entryPointOutput_u002e_aa: f32;
var<private> u0040_entryPointOutput_u002e_fill: f32;

fn main_1() {
    let _e21 = input_u002e_pos_1;
    let _e22 = input_u002e_uv_1;
    let _e23 = input_u002e_color_1;
    let _e24 = input_u002e_radius_1;
    let _e25 = input_u002e_stroke_1;
    let _e26 = input_u002e_aa_1;
    let _e27 = input_u002e_type_1;
    let _e28 = input_u002e_alpha_1;
    let _e29 = input_u002e_fill_1;
    let _e34 = unnamed.viewProj;
    u0040_entryPointOutput_u002e_position = (vec4<f32>(_e21.x, _e21.y, 0f, 1f) * transpose(_e34));
    u0040_entryPointOutput_u002e_uv = _e22;
    u0040_entryPointOutput_u002e_color = vec4<f32>(_e23.x, _e23.y, _e23.z, (_e23.w * _e28));
    u0040_entryPointOutput_u002e_type = _e27;
    u0040_entryPointOutput_u002e_radius = _e24;
    u0040_entryPointOutput_u002e_stroke = _e25;
    u0040_entryPointOutput_u002e_aa = _e26;
    u0040_entryPointOutput_u002e_fill = _e29;
    return;
}

@vertex 
fn main(@location(0) input_u002e_pos: vec2<f32>, @location(1) input_u002e_uv: vec2<f32>, @location(2) input_u002e_color: vec4<f32>, @location(3) input_u002e_radius: f32, @location(4) input_u002e_stroke: f32, @location(5) input_u002e_aa: f32, @location(6) input_u002e_type: f32, @location(7) input_u002e_alpha: f32, @location(8) input_u002e_fill: f32) -> VertexOutput {
    input_u002e_pos_1 = input_u002e_pos;
    input_u002e_uv_1 = input_u002e_uv;
    input_u002e_color_1 = input_u002e_color;
    input_u002e_radius_1 = input_u002e_radius;
    input_u002e_stroke_1 = input_u002e_stroke;
    input_u002e_aa_1 = input_u002e_aa;
    input_u002e_type_1 = input_u002e_type;
    input_u002e_alpha_1 = input_u002e_alpha;
    input_u002e_fill_1 = input_u002e_fill;
    main_1();
    let _e27 = u0040_entryPointOutput_u002e_position.y;
    u0040_entryPointOutput_u002e_position.y = -(_e27);
    let _e29 = u0040_entryPointOutput_u002e_position;
    let _e30 = u0040_entryPointOutput_u002e_uv;
    let _e31 = u0040_entryPointOutput_u002e_color;
    let _e32 = u0040_entryPointOutput_u002e_type;
    let _e33 = u0040_entryPointOutput_u002e_radius;
    let _e34 = u0040_entryPointOutput_u002e_stroke;
    let _e35 = u0040_entryPointOutput_u002e_aa;
    let _e36 = u0040_entryPointOutput_u002e_fill;
    return VertexOutput(_e29, _e30, _e31, _e32, _e33, _e34, _e35, _e36);
}
