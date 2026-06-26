shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert;

uniform vec4 bubble_color : source_color = vec4(0.0, 0.6, 0.8, 0.3);
uniform vec4 rim_color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
uniform float rim_power : hint_range(0.1, 10.0) = 3.0;

// Vertex Displacement (Wobble)
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float wobble_displacement : hint_range(0.0, 0.5) = 0.05;
uniform float wobble_speed : hint_range(0.0, 5.0) = 1.0;

// Texture Animation
uniform vec2 texture_speed = vec2(0.05, 0.02);
uniform float texture_scale = 2.0;

// progress: 0 = idle checkpoint, 1 = bright "follow me" beacon while travelling
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// vanish_amount: timeout-only dissolve sweep (0 = off)
uniform float vanish_amount : hint_range(0.0, 1.0) = 0.0;

uniform float mesh_height = 2.0;
uniform float flash_width = 0.25;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec4 guide_color : source_color = vec4(0.35, 1.0, 0.95, 1.0);
uniform float guide_scale : hint_range(0.0, 0.6) = 0.22;
uniform float guide_emission : hint_range(0.0, 30.0) = 14.0;
uniform float guide_pulse_speed : hint_range(0.0, 12.0) = 4.0;
uniform float guide_band_speed : hint_range(0.0, 10.0) = 2.5;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;

	vec2 noise_uv = UV + TIME * wobble_speed * 0.1;
	float noise_val = texture(noise_texture, noise_uv).r;

	float pulse = sin(TIME * guide_pulse_speed) * 0.5 + 0.5;
	float guide = progress * (0.82 + 0.18 * pulse);

	VERTEX += NORMAL * noise_val * wobble_displacement;
	VERTEX += NORMAL * guide * guide_scale;
	VERTEX *= 1.0 + guide * guide_scale;
}

void fragment() {
	vec2 moving_uv = (UV * texture_scale) + (TIME * texture_speed);
	float noise_surface = texture(noise_texture, moving_uv).r;

	float fresnel = pow(1.0 - dot(NORMAL, VIEW), rim_power);

	float normalized_y = 1.0 - ((local_y / (mesh_height * 0.5)) * 0.5 + 0.5);

	float guide = progress;
	float pulse = sin(TIME * guide_pulse_speed * 1.7) * 0.5 + 0.5;
	float band_phase = fract(UV.x * 10.0 - TIME * guide_band_speed);
	float chase_band = smoothstep(0.42, 0.0, abs(band_phase - 0.5)) * guide;
	float halo = pow(fresnel, max(rim_power * 0.35, 0.1));

	vec3 base_blend = mix(bubble_color.rgb, rim_color.rgb, noise_surface * 0.4);
	vec3 idle_albedo = mix(base_blend, rim_color.rgb, fresnel);

	vec3 guide_albedo = mix(idle_albedo, guide_color.rgb, guide * (0.55 + 0.25 * pulse));
	ALBEDO = mix(guide_albedo, flash_color.rgb, chase_band * 0.65);

	vec3 idle_emission = rim_color.rgb * fresnel * 2.0;
	vec3 guide_glow = guide_color.rgb * guide * guide_emission * (0.65 + 0.35 * pulse) * (halo + 0.35);
	vec3 band_glow = flash_color.rgb * chase_band * guide_emission * 0.35;
	EMISSION = idle_emission + guide_glow + band_glow;

	float idle_alpha = mix(bubble_color.a, rim_color.a, fresnel + (noise_surface * 0.2));
	float guide_alpha = mix(idle_alpha, clamp(idle_alpha + guide * 0.45, 0.0, 1.0), guide);

	// Timeout reset: brief downward dissolve (only when vanish_amount > 0)
	float dissolve_mask = 1.0;
	float flash_edge = 0.0;
	if (vanish_amount > 0.001) {
		dissolve_mask = step(vanish_amount, normalized_y);
		flash_edge = smoothstep(vanish_amount + flash_width, vanish_amount, normalized_y) * dissolve_mask;
		ALBEDO = mix(ALBEDO, flash_color.rgb, flash_edge);
		EMISSION = mix(EMISSION, flash_color.rgb * flash_edge * 15.0, flash_edge);
	}

	ALPHA = guide_alpha * dissolve_mask;
	ALPHA = max(ALPHA, flash_edge);

	ROUGHNESS = mix(0.1, 0.02, guide);
	SPECULAR = mix(0.5, 0.85, guide);
}
