shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

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

void vertex() {
	// Sample noise using time to create a shifting offset
	vec2 noise_uv = UV + TIME * wobble_speed * 0.1;
	float noise_val = texture(noise_texture, noise_uv).r;

	// Push the vertices outward along their normals based on the noise map
	VERTEX += NORMAL * noise_val * wobble_displacement;
}

void fragment() {
	// 1. Panning Caustic Noise Map
	vec2 moving_uv = (UV * texture_scale) + (TIME * texture_speed);
	float noise_surface = texture(noise_texture, moving_uv).r;

	// 2. The Fresnel Effect (Rim Lighting)
	// Calculates how sharp the viewing angle is relative to the camera
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), rim_power);

	// 3. Composition
	// Blend base color with the animated surface noise
	vec3 base_blend = mix(bubble_color.rgb, rim_color.rgb, noise_surface * 0.4);

	// Apply the Fresnel effect to make the edges heavily stylized and emissive
	ALBEDO = mix(base_blend, rim_color.rgb, fresnel);
	EMISSION = rim_color.rgb * fresnel * 2.0; // Drives the Godot HDR Glow

	// Keep the center translucent so the shipwreck inside is visible
	ALPHA = mix(bubble_color.a, rim_color.a, fresnel + (noise_surface * 0.2));

	// Make it look smooth and glass-like
	ROUGHNESS = 0.1;
	SPECULAR = 0.5;
}