shader_type spatial;

#include "HeightMapReader.gdshaderinc"

render_mode unshaded,cull_front, depth_prepass_alpha;

group_uniforms Normals;
uniform sampler2D normal1;
uniform sampler2D normal2;
uniform vec2 normal_scale;
uniform float normal_churn_speed = 0.5;

group_uniforms Colors;
uniform vec3 deep_color = vec3(0.0, 0.37, 0.42);  // Deep water color
uniform vec3 shallow_color = vec3(0.0, 0.6, 0.7); // Lighter edges

group_uniforms Waves;
uniform float wave_amplitude = 1;  // Height of the waves
uniform float wave_length = .1;    // Distance between wave peaks
uniform float wave_speed = 2.0;      // Speed of wave movement
const int wave_count = 3;          // Number of waves summed
uniform float wave_time = 0.0;

varying vec3 worldPos;
varying vec3 waterPos;

// Randomized wave directions
const vec2 wave_directions[5] = vec2[5](
    vec2(1.0, 0.5),  // Diagonal wave 1
    vec2(-0.7, 1.0), // Diagonal wave 2
    vec2(0.5, -0.8), // Diagonal wave 3
    vec2(-1.0, -0.3), // Diagonal wave 4
	vec2(-1.0, 3.0) // Diagonal wave 4
);

void vertex() {
    worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 pos = worldPos.xz;

    float total_displacement = 0.0;
    float total_displacement_x = 0.0;
    float total_displacement_z = 0.0;

    vec2 dx = vec2(1.0, 0.0);
    vec2 dz = vec2(0.0, 1.0);

    for (int i = 0; i < wave_count; i++) {
        vec2 dir = normalize(wave_directions[i]);
        float frequency = (1.0 / max(0.0001, wave_length)) * float(i + 1);
        float phase = wave_time * wave_speed * float(i + 1) * 0.18;

        float wave = sin(dot(pos, dir) * frequency + phase);
        float amplitude = wave_amplitude / float(i + 1);

        total_displacement += wave * amplitude;

        float wave_x = sin(dot(pos + dx, dir) * frequency + phase) * amplitude;
        float wave_z = sin(dot(pos + dz, dir) * frequency + phase) * amplitude;

        total_displacement_x += wave_x;
        total_displacement_z += wave_z;
    }

    VERTEX.y += total_displacement;

    waterPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    vec3 tangent_x = vec3(1.0, total_displacement_x - total_displacement, 0.0);
    vec3 tangent_z = vec3(0.0, total_displacement_z - total_displacement, 1.0);
    vec3 normal = normalize(cross(tangent_z, tangent_x));

    NORMAL = normalize((MODEL_MATRIX * vec4(normal, 0.0)).xyz);
}


void fragment() {
	// Calculate the water normals
	vec2 uv1 = UV*normal_scale+vec2(TIME*normal_churn_speed,0.0);
	vec2 uv2 = UV*normal_scale*10.0-vec2(TIME*normal_churn_speed*0.1,TIME*normal_churn_speed*0.05);
	vec3 n1 = texture(normal1, uv1).rgb * 2.0 - 1.0;
    vec3 combined_normal = normalize(n1 + vec3(0.0, 0.0, 0.0));

	// Calculate the fresnel effect
	float fresnel = 1.2-dot(NORMAL,VIEW);
	fresnel = clamp(pow(fresnel,1),0.0,1.0);
	// Blend colors based on the fresnel effect
	vec3 final_color = mix(deep_color,shallow_color,fresnel);
	float roughness = .05;//mix(.15,.8,fresnel);
	float specular = .3; //mix(.01,0.6,fresnel);

	float dist = length(waterPos-CAMERA_POSITION_WORLD);
	float alpha = 1.0;
	if(dist<1.0)
	{
		alpha = mix(0.0,1.0,pow((dist),0.5));
	}




	ALBEDO = clamp(mix(final_color,shallow_color,combined_normal),vec3(0.,0.,0.),vec3(1.,1.,1.));

	// other settings
	SPECULAR = 0.0;
	ROUGHNESS = 0.0;
	ALPHA = alpha;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
