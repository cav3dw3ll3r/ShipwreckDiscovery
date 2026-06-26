shader_type spatial;

render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_map;
uniform sampler2D normal_map;
uniform sampler2D roughness_map;

uniform float displacement_strength = 0.1;
uniform float scroll_speed = 0.01;

void vertex() {
	vec3 disp_normal = NORMAL;
	vec2 uv = UV;
}

void fragment() {
	vec2 uv = UV+TIME*scroll_speed;

	// Albedo
	vec4 albedo_tex = texture(albedo_map, uv);
	ALBEDO = albedo_tex.rgb;

	// Normal
	vec3 normal_tex = texture(normal_map, uv).rgb;
	NORMAL_MAP = normal_tex;

	// Roughness
	float roughness_val = texture(roughness_map, uv).r;
	ROUGHNESS = roughness_val;
}
