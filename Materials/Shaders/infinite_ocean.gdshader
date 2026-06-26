shader_type spatial;
// depth_test_blend allows us to read what's behind the transparent water
render_mode unshaded, blend_mix, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

group_uniforms Colors;
uniform vec3 deep_color : source_color = vec3(0.05, 0.15, 0.35);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.75, 0.95);
uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 0.95); // Foam line color

group_uniforms Normals;
uniform sampler2D normal_map : hint_normal;
uniform float normal_scale = 10.0;
uniform float normal_churn_speed = 0.2;

group_uniforms ProximityFade;
const float fade_distance = 0.095;
const float fade_softness = 0.05;

// Global uniform to read the scene depth buffer
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = UV * normal_scale
			+ vec2(TIME * normal_churn_speed * 0.01, TIME * normal_churn_speed * 0.003);

	vec3 wave_data = texture(normal_map, uv).rgb * 2.0 - 1.0;
	wave_data = normalize(wave_data);

	vec3 warped_normal = normalize(NORMAL + wave_data * 0.1);
	float ndotv = max(dot(warped_normal, VIEW), 0.0);
	float fresnel = 1.0 - ndotv;
	fresnel = fresnel * fresnel;

	vec3 base_color = mix(deep_color, horizon_color, fresnel);
	
	// --- HULL INTERSECTION FOAM LOGIC ---
	// 1. Get the depth of the object behind the water (the boat hull)
	float depth = texture(depth_texture, SCREEN_UV).r;

	// 4. Blend the foam color into the base water right at the intersection seam
	vec3 final_surface_color = mix(base_color,vec3(1.,1.,1.),depth);
	
	// --- CAMERA SPACE FILL LOGIC ---
	float distance_to_camera = -VERTEX.z;
	float face_proximity = 1.0 - smoothstep(fade_distance, fade_distance + 0.25, distance_to_camera);
	
	ALBEDO = mix(final_surface_color, vec3(0.125, 0.392, 0.427), face_proximity);
	
	// --- MVP PROXIMITY FADE ---
	float proximity_alpha = smoothstep(fade_distance - fade_softness, fade_distance, distance_to_camera);
	
	ALPHA = proximity_alpha;
}