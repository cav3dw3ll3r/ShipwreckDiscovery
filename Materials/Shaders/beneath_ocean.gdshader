shader_type spatial;
// Kept cull_front for the underside orientation, added diffuse/specular settings to match top execution
render_mode unshaded, blend_mix, depth_draw_always, cull_front, diffuse_lambert, specular_schlick_ggx;

group_uniforms Colors;
uniform vec3 deep_color : source_color = vec3(0.05, 0.15, 0.35);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.75, 0.95);

group_uniforms Normals;
uniform sampler2D normal_map : hint_normal;
uniform float normal_scale = 0.1; 
uniform float normal_churn_speed = 0.2;

group_uniforms ProximityFade;
// Matched to top-side settings for a seamless transition window
const float fade_distance = 0.095;
const float fade_softness = 0.05;
// Global uniform to read the scene depth buffer
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 world_uv = world_pos.xz * normal_scale 
			+ vec2(TIME * normal_churn_speed * 0.01, TIME * normal_churn_speed * 0.003);

	vec3 wave_data = texture(normal_map, world_uv).rgb * 2.0 - 1.0;
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

	// --- MVP PROXIMITY FADE LOGIC ---
	float proximity_alpha = smoothstep(fade_distance - fade_softness, fade_distance, distance_to_camera);
	
	ALPHA = proximity_alpha;
}