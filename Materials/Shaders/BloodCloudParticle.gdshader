shader_type canvas_item;

uniform sampler2D noise_tex;
uniform vec4 blood_color : source_color;
uniform float dissolve_speed = 0.5;
uniform float soft_edge = 0.2;
uniform float time_offset = 0.0;

void fragment() {
    vec2 uv = UV;
    float noise = texture(noise_tex, uv * 2.0).r;

    float dissolve = fract(TIME * dissolve_speed + time_offset);
    float mask = smoothstep(dissolve - soft_edge, dissolve + soft_edge, noise);

    COLOR = blood_color * mask;

    // Optional color shift from dark to diluted
    COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.5, 0.5), dissolve);
}