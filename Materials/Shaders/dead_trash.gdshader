shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dent_shadow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 dissolve_color : source_color = vec4(0.95, 0.85, 0.35, 1.0);
uniform float emission_strength = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_multiplier : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.75;
uniform float color_strength : hint_range(0.0, 1.0) = 0.85;
uniform float color_brightness : hint_range(0.5, 2.0) = 1.45;
uniform float crumple_strength : hint_range(0.0, 0.12) = 0.045;
uniform float dent_frequency : hint_range(1.0, 32.0) = 14.0;
uniform sampler2D crumple_noise_tex : hint_default_white;
uniform float appearance_seed = 1.0;

uniform vec3 movement_vector = vec3(0.0, 0.0, 0.0);
uniform float flexibility = 0.2;
uniform float max_radius = 0.25;
uniform vec3 local_gravity_dir = vec3(0.0, -1.0, 0.0);
uniform float gravity_strength = 0.04;

uniform vec3 local_tube_origin = vec3(0.0);
uniform vec3 local_tube_axis = vec3(0.0, 1.0, 0.0);
uniform float mesh_z_min = -0.1;
uniform float mesh_z_max = 0.1;
uniform float insertion_progress : hint_range(0.0, 1.0) = 0.35;
uniform float tube_radius = 0.055;
uniform float funnel_width = 0.03;

varying float v_funnel_glow;
varying float v_crumple_mix;
varying vec3 v_can_color;

const float my_tau = 6.28318530718;

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

void vertex() {
	float seed = max(appearance_seed, 1.0);
	float instance_strength = crumple_strength * mix(0.55, 1.25, hash_float(seed + 61.0));

	float height_val = VERTEX.z;
	vec3 inward_dir = -normalize(vec3(VERTEX.x, VERTEX.y, 0.0));
	float angle = atan(VERTEX.y, VERTEX.x);

	float cap_mask = smoothstep(0.48, 0.25, abs(height_val));
	float squash_factor = 1.0 - (instance_strength * 2.5);
	VERTEX.z *= squash_factor;

	float angle_uv = angle / my_tau + 0.5;
	vec2 noise_uv = vec2(angle_uv, height_val + 0.5) * (dent_frequency * 0.1);
	vec2 uv_offset = vec2(
		hash_float(seed + 13.0),
		hash_float(seed + 29.0)
	);

	float raw_noise = textureLod(crumple_noise_tex, noise_uv + uv_offset, 0.0).r;
	float sharp_dent = pow(raw_noise, 2.5);
	float final_collapse = sharp_dent * instance_strength * cap_mask;
	VERTEX += inward_dir * final_collapse;

	v_crumple_mix = clamp(final_collapse / max(crumple_strength, 0.0001), 0.0, 1.0);
	v_can_color = random_can_color(seed);

	float dist = length(VERTEX);
	float weight = smoothstep(0.0, max_radius, dist);
	vec3 v_rag = VERTEX + movement_vector * weight * flexibility + local_gravity_dir * gravity_strength * weight;

	vec3 norm_axis = normalize(local_tube_axis);
	vec3 p = v_rag - local_tube_origin;
	float z_vert = dot(p, norm_axis);
	vec3 closest_axis_point = local_tube_origin + norm_axis * z_vert;
	vec3 radial_vec = v_rag - closest_axis_point;
	float r_len = length(radial_vec);
	vec3 r_dir = radial_vec / (r_len + 0.0001);
	vec3 squished_pos = local_tube_origin + norm_axis * z_vert + r_dir * min(r_len, tube_radius);

	float local_insertion_threshold = mix(mesh_z_max, mesh_z_min, insertion_progress);
	float is_inside = step(local_insertion_threshold, z_vert);
	float dist_to_threshold = abs(z_vert - local_insertion_threshold);
	v_funnel_glow = 1.0 - smoothstep(0.0, funnel_width, dist_to_threshold);

	VERTEX = mix(v_rag, squished_pos, is_inside);
}

void fragment() {
	vec3 raw_albedo = texture(albedo_texture, UV).rgb;
	vec3 albedo = raw_albedo * albedo_tint.rgb;
	float white_mask = smoothstep(0.70, 0.96, dot(raw_albedo, vec3(0.299, 0.587, 0.114)));
	vec3 bright_color = v_can_color * color_brightness;
	vec3 remapped = mix(albedo, bright_color * max(albedo, vec3(0.45)), white_mask * color_strength);
	vec3 dented = mix(remapped, dent_shadow.rgb, v_crumple_mix * 0.22);
	vec3 with_funnel = mix(dented, dissolve_color.rgb, v_funnel_glow);
	vec3 dissolved = mix(with_funnel, dissolve_color.rgb, progress);
	vec3 whitened = mix(dissolved, vec3(1.0), progress * 0.45);

	ALBEDO = whitened;
	EMISSION = dissolve_color.rgb * (v_funnel_glow + 0.2) * emission_strength * (1.0 - progress);
	METALLIC = metallic;
	ROUGHNESS = clamp(0.85 * roughness_multiplier, 0.0, 1.0);
	ALPHA = 1.0 - progress;
}
