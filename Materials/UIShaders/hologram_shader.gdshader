shader_type spatial;
render_mode blend_add, cull_back, depth_draw_opaque, unshaded;

uniform vec4 tint_color;
uniform float line_speed = 1.0;
uniform float line_frequency = 20.0;
uniform float glow_strength = 0.3;
uniform float fresnel_strength = 1.0;
uniform float fresnel_power = 3.0;

void vertex()
{
	VERTEX+=NORMAL*0.001;
}

void fragment() {
    float time = TIME;

    // Horizontal glowing lines
    float lines = sin((VERTEX.y + time * line_speed) * line_frequency);
    float glow = abs(lines) * glow_strength;

    // Fresnel term
    vec3 view_dir = normalize(VIEW);
    vec3 normal_dir = normalize(NORMAL);
    float fresnel = pow(1.0 - dot(view_dir, normal_dir), fresnel_power);

    // Color and transparency
    vec4 base_color = tint_color;
    base_color.rgb += glow + fresnel * fresnel_strength;

    // Fresnel-driven alpha (0 when viewed head-on, 1 at glancing angles)
    float alpha = clamp(fresnel * fresnel_strength, 0.0, 1.0);
    ALBEDO = base_color.rgb;
    ALPHA = alpha;
	EMISSION = base_color.rgb*2.0;
}
