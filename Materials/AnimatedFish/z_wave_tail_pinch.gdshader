shader_type spatial;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;

uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.12;
uniform float wave_frequency : hint_range(0.1, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.1, 10.0) = 2.5;
uniform float tail_start : hint_range(-1.0, 1.0) = 0.0;

/* Pinch controls */
uniform float pinch_strength : hint_range(0.0, 1.0) = 0.4;
uniform float pinch_falloff : hint_range(0.1, 5.0) = 2.0;
uniform float pinch_start : hint_range(-1.0, 1.0) = 0.4;
uniform float pinch_center_y : hint_range(-1.0, 1.0) = 0.0;

void vertex() {
	vec3 p = VERTEX;

	float phase_offset = INSTANCE_CUSTOM.x;

	// Head → tail weighting
	float wag_factor   = smoothstep(tail_start,  1.0, -p.z);
	float pinch_factor = smoothstep(pinch_start, 1.0, -p.z);

	// Shared wave phase
	float phase = p.z * wave_frequency + TIME * wave_speed + phase_offset;

	// Side-to-side wag
	p.x += sin(phase) * wave_amplitude * wag_factor;

	// Vertical pinch around configurable Y center
	float y_from_center = p.y - pinch_center_y;
	float vertical_mask = pow(abs(y_from_center), pinch_falloff);

	float pinch =
		pinch_strength
		* pinch_factor
		* vertical_mask;

	p.y -= sign(y_from_center) * pinch;

	VERTEX = p;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
}
