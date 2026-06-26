shader_type spatial;
render_mode unshaded,depth_draw_never,depth_test_disabled,fog_disabled;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float damage_impulse : hint_range(0.0, 1.0) = 0.0;
uniform float damage_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 damage_tint_color : source_color = vec3(0.55, 0.04, 0.04);
uniform float damage_vein_strength : hint_range(0.0, 1.0) = 0.25;
uniform float damage_vein_scale : hint_range(1.0, 80.0) = 34.0;
uniform float damage_noise_seed = 1.0;
uniform float damage_noise_scale : hint_range(1.0, 60.0) = 18.0;
uniform float damage_noise_speed : hint_range(0.0, 8.0) = 2.6;
uniform float damage_noise_impulse_strength : hint_range(0.0, 1.0) = 0.08;
uniform float damage_noise_intensity_strength : hint_range(0.0, 1.0) = 0.2;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
    float uv_y = UV.y;
    float dist = abs(uv_y - 0.5);

	float noise_time = TIME * damage_noise_speed;
	vec2 noise_uv = UV * damage_noise_scale + vec2(noise_time, noise_time * 0.61 + damage_noise_seed);
	float noise_val = value_noise(noise_uv);
	float signed_noise = (noise_val - 0.5) * 2.0;

	float impulse_noise = signed_noise * damage_noise_impulse_strength * damage_intensity;
    float effective_progress = clamp(progress - damage_impulse + impulse_noise, 0.0, 1.0);
    float threshold = (effective_progress - 0.05 * 0.5) - pow(UV.x - 0.5, 2.0);

    if (dist < threshold) {
        discard;
    }

	float intensity_noise = signed_noise * damage_noise_intensity_strength * damage_intensity;
	float intensity = clamp(damage_intensity + intensity_noise, 0.0, 1.0);
	float vein_wave = sin(UV.y * damage_vein_scale + sin(UV.x * 9.0) * 2.5);
	float vein_pattern = smoothstep(0.72, 0.97, vein_wave * 0.5 + 0.5);
	float vein_mix = vein_pattern * damage_vein_strength * intensity;
	vec3 base_color = vec3(0.0, 0.0, 0.0);
	vec3 tint_color = mix(base_color, damage_tint_color, intensity * 0.85);
	ALBEDO = mix(tint_color, damage_tint_color * 1.25, vein_mix * 0.6);
}