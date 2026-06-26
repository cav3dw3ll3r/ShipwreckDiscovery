shader_type spatial;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform vec3 color_correction: source_color;
uniform float brightness_threshold = 0.5;
uniform float correction_strength=0.5;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.12;
uniform float wave_frequency : hint_range(0.1, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.1, 10.0) = 2.5;
uniform float tail_start : hint_range(-1.0, 1.0) = 0.0;

void vertex() {
	vec3 p = VERTEX;

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
    vec3 tex_color = texture(albedo_tex, UV).rgb;

    // Convert 0-255 color to 0-1 range
    vec3 eye_color = vec3(32.0/255.0, 23.0/255.0, 36.0/255.0);
	vec3 skin_color = vec3(190./255.,156./255.,149./255.);
    // Compute a small tolerance, so you catch near-matches too
    float tolerance = 0.3;

    // Check if tex_color is close to eye_color
    float is_eye = step(0.0, tolerance - distance(tex_color, eye_color));
	float is_skin = step(0.0, tolerance - distance(tex_color,skin_color));
    // Only recolor if it's NOT the eye
    ALBEDO = mix(tex_color, color_correction, correction_strength * (1.0 - (is_eye+is_skin)));

    NORMAL_MAP = texture(normal_tex, UV).rgb;
}



