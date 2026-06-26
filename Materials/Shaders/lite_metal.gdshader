shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

uniform vec4 albedo_tint : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform sampler2D texture_albedo : source_color;
uniform sampler2D texture_normal : hint_normal;

uniform float specular_intensity : hint_range(0, 5) = 1.0;
uniform float shininess : hint_range(1, 100) = 25.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 3.0;
uniform vec3 rim_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	// 1. Basic Texture & Normal
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb * albedo_tint.rgb;
	
	// Unpack the normal map properly
	vec3 normal = texture(texture_normal, UV).rgb * 2.0 - 1.0;
	NORMAL = normalize(TANGENT * normal.x + BINORMAL * normal.y + NORMAL * normal.z);
	
	// 2. The Fresnel Calculation (The "Aluminum Sheen")
	// VIEW is the vector from the fragment to the camera
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	// 3. Fake Specular (since we're avoiding the PBR specular workflow)
	// We'll use the light direction logic in the light() function for accuracy, 
	// or just bake a soft "rim" here.
	EMISSION = rim_color * fresnel;
}

void light() {
	// 4. Manual Blinn-Phong Specular for that "Old School" feel
	vec3 half_vector = normalize(VIEW + LIGHT);
	float spec_dot = clamp(dot(NORMAL, half_vector), 0.0, 1.0);
	float specular = pow(spec_dot, shininess) * specular_intensity;
	
	// Apply diffuse and specular
	float diffuse_dot = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diffuse_dot;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * specular;
}