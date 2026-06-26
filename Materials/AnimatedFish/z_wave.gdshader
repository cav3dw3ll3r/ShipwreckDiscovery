shader_type spatial;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;

uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.12;
uniform float wave_frequency : hint_range(0.1, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.1, 10.0) = 2.5;
uniform float tail_start : hint_range(-1.0, 1.0) = 0.0;

void vertex() {
	vec3 p = VERTEX;

	// Stable per-fish phase from MultiMesh custom data (set in MultiFishController / MultiFishLODController).
	float phase_offset = INSTANCE_CUSTOM.x;

	// Head → tail weighting (head +Z, tail −Z)
	float tail_factor = smoothstep(tail_start, 1.0, -p.z);

	// Same wave, now traveling down Z
	float wave =
		sin(p.z * wave_frequency + TIME * wave_speed + phase_offset)
		* wave_amplitude
		* tail_factor;

	// Side-to-side wag in X
	p.x += wave;

	VERTEX = p;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
}
