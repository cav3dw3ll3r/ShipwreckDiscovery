shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
// Normal Mapping Uniforms
uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(-16.0, 16.0) = 1.0;

// Hard Light / Cel Shading Uniforms
uniform float light_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float light_smoothness : hint_range(0.0, 0.2) = 0.01; // Tiny fallback to prevent jagged pixel aliasing

// Glow / Emission Uniforms
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 0.0;

void vertex() {
	// Standard vertex pass-through
}

void fragment() {
	ALBEDO = albedo.rgb;
	vec4 normal = texture(texture_normal,UV+TIME*0.02);
	ALPHA = normal.r;
	
	// Apply Configurable Glow
	// Enforcing an energy multiplier allows the glow to trigger Godot's WorldEnvironment HDR Bloom
	EMISSION = glow_color.rgb * glow_intensity*normal.r;
}

void light() {
	// NdotL calculation incorporates the normals processed in the fragment shader
	float dot_product = dot(NORMAL, LIGHT);
	
	// Standardize the -1.0 to 1.0 dot product range into a 0.0 to 1.0 range
	float half_lambert = dot_product * 0.5 + 0.5;
	
	// Create the hard light cutoff using smoothstep with a tight window to avoid aliasing artifacts
	float hard_light_mask = smoothstep(
		light_threshold - light_smoothness, 
		light_threshold + light_smoothness, 
		half_lambert
	);
	
	// Blend the incoming light color/attenuation with our hard mask
	vec3 diffuse_light = LIGHT_COLOR * ATTENUATION * hard_light_mask;
	
	// Inject the calculated hard light into the diffuse pipeline
	DIFFUSE_LIGHT += diffuse_light * ALBEDO;
}