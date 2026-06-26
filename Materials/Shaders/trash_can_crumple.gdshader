shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

const float my_tau = 6.28318530718;

uniform sampler2D albedo_texture : source_color;

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dent_shadow : source_color = vec4(0.16, 0.17, 0.16, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_multiplier : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.75;
uniform float color_strength : hint_range(0.0, 1.0) = 0.85;
uniform float color_brightness : hint_range(0.5, 2.0) = 1.45;
uniform float crumple_strength : hint_range(0.0, 0.12) = 0.045;
uniform float dent_frequency : hint_range(1.0, 32.0) = 14.0;

varying float v_crumple_mix;
varying vec3 v_can_color;

float hash_float(float n) {
	return fract(sin(n) * 43758.5453123);
}

vec3 random_can_color(float seed) {
	vec3 color_a = vec3(1.00, 0.05, 0.02);
	vec3 color_b = vec3(0.00, 0.34, 1.00);
	vec3 color_c = vec3(0.00, 0.95, 0.18);
	vec3 color_d = vec3(1.00, 0.82, 0.00);
	float pick = hash_float(seed + 101.0);
	vec3 first_pair = mix(color_a, color_b, step(0.25, pick));
	vec3 second_pair = mix(color_c, color_d, step(0.75, pick));
	return mix(first_pair, second_pair, step(0.5, pick));
}

// Add the new noise texture uniform
uniform sampler2D crumple_noise_tex : hint_default_white;

void vertex() {
	float seed = float(INSTANCE_ID) + 1.0;
	float instance_strength = crumple_strength * mix(0.55, 1.25, hash_float(seed + 61.0));
	
	// ==========================================
	// CONFIGURATION: SET BASED ON MESH ORIENTATION
	// ==========================================
	// If can runs along Z (Forward/Backward):
	float height_val = VERTEX.z;
	vec3 inward_dir = -normalize(vec3(VERTEX.x, VERTEX.y, 0.0));
	float angle = atan(VERTEX.y, VERTEX.x);
	
	// If your can runs along Y (Up/Down), uncomment these lines instead:
	// float height_val = VERTEX.y;
	// vec3 inward_dir = -normalize(vec3(VERTEX.x, 0.0, VERTEX.z));
	// float angle = atan(VERTEX.z, VERTEX.x);
	// ==========================================

	// 1. HEIGHT MASK & VERTICAL SQUASH
	// Uses the relative height_val instead of hardcoded VERTEX.y
	float cap_mask = smoothstep(0.48, 0.25, abs(height_val));
	
	float squash_factor = 1.0 - (instance_strength * 2.5); 
	
	// Apply squash specifically to the length axis
	if (height_val == VERTEX.z) {
		VERTEX.z *= squash_factor;
	} else if (height_val == VERTEX.y) {
		VERTEX.y *= squash_factor;
	}

	// 2. STOCHASTIC TEXTURE PROJECTON
	float angle_uv = angle / my_tau + 0.5;
	vec2 noise_uv = vec2(angle_uv, height_val + 0.5) * (dent_frequency * 0.1);
	
	vec2 uv_offset = vec2(
		hash_float(seed + 13.0),
		hash_float(seed + 29.0)
	);
	
	float raw_noise = textureLod(crumple_noise_tex, noise_uv + uv_offset, 0.0).r;
	float sharp_dent = pow(raw_noise, 2.5);
	
	// 3. APPLY STRUCTURAL COLLAPSE
	float final_collapse = sharp_dent * instance_strength * cap_mask;
	VERTEX += inward_dir * final_collapse;

	// 4. INTERPOLATION VALUES FOR FRAGMENT
	v_crumple_mix = clamp(final_collapse / max(crumple_strength, 0.0001), 0.0, 1.0);
	v_can_color = random_can_color(seed);
}


void fragment() {
	vec3 raw_albedo = texture(albedo_texture, UV).rgb;
	vec3 albedo = raw_albedo * albedo_tint.rgb;
	float white_mask = smoothstep(0.70, 0.96, dot(raw_albedo, vec3(0.299, 0.587, 0.114)));
	vec3 bright_color = v_can_color * color_brightness;
	vec3 remapped = mix(albedo, bright_color * max(albedo, vec3(0.45)), white_mask * color_strength);

	ALBEDO = mix(remapped, dent_shadow.rgb, v_crumple_mix * 0.22);
	METALLIC = metallic;
	EMISSION = bright_color * white_mask * 0.06;
}
