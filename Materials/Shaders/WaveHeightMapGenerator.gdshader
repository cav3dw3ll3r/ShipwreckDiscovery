shader_type canvas_item;

group_uniforms Waves;
uniform float wave_amplitude = 1;  // Height of the waves
uniform float wave_length = .1;    // Distance between wave peaks
uniform float wave_speed = 2.0;      // Speed of wave movement
uniform int wave_count = 5;          // Number of waves summed

varying vec3 worldPos;

// Randomized wave directions
const vec2 wave_directions[5] = vec2[5](
    vec2(1.0, 0.5),  // Diagonal wave 1
    vec2(-0.7, 1.0), // Diagonal wave 2
    vec2(0.5, -1.0), // Diagonal wave 3
    vec2(-1.0, -0.3), // Diagonal wave 4
	vec2(-1.0, 3.0) // Diagonal wave 4
);

void vertex() {
}

void fragment()
{
	float total_displacement = 0.0;
    for (int i = 0; i < wave_count; i++) {
	    vec2 dir = normalize(wave_directions[i]); // Normalize directions
	    float frequency = (1.0 / wave_length) * float(i + 1);
	    float phase = TIME * wave_speed * float(i + 1) * 0.2; // Different speeds
	    float wave = sin(dot(UV, dir) * frequency + phase); // Move in X & Z

	    total_displacement += wave * (wave_amplitude / float(i + 1)); // Sum waves with decreasing influence
    }
	vec4 color = vec4(total_displacement,total_displacement,total_displacement,1.0);
	COLOR = color;
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
