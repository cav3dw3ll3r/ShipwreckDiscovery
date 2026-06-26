shader_type canvas_item;

uniform sampler2D caustics_tex;
uniform vec2 scroll_speed = vec2(0.1, 0.07);

void fragment() {
    vec2 uv = UV + scroll_speed * TIME;
    COLOR = texture(caustics_tex, uv);
}
