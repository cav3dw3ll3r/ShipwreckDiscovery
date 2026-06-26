shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D albedo_texture;
uniform sampler2D mask_texture;
uniform sampler2D mask_2_texture;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

void vertex() {
    // Get the model position in world space
    vec3 model_pos = MODEL_MATRIX[3].xyz;

    // For VR, we'll use the eye position directly
    vec3 camera_pos = CAMERA_POSITION_WORLD;
    vec3 to_camera = normalize(camera_pos - model_pos);

    // Calculate the right vector
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_camera));
    // Keep up vector strictly vertical
    vec3 up = vec3(0.0, 1.0, 0.0);
    // Recalculate forward vector to ensure orthogonality
    vec3 forward = normalize(cross(right, up));

    // Build the billboard matrix
    mat4 billboard_matrix = mat4(
        vec4(right, 0.0),
        vec4(up, 0.0),
        vec4(forward, 0.0),
        vec4(model_pos, 1.0)
    );

    MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;
}

void fragment() {
	vec2 uv = UV-TIME*0.02;
    vec4 albedo = texture(albedo_texture, UV);
	float alpha_mask = clamp(1.0-texture(mask_texture,uv).r,0.0,1.0);
	float alpha_mask_2 = clamp(texture(mask_2_texture,UV+TIME*0.01).r,0.0,1.0);
	alpha_mask_2 = alpha_mask_2*alpha_mask_2;
	float fade_distance = 15.0;

    vec3 world_camera = (INV_VIEW_MATRIX * vec4(vec3(0.0), 1.0)).xyz;
	vec4 a = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);

	float linear_distance = distance(a.xyz,world_camera);

	float fade_start = 0.0;  // fully visible after this distance
	float fade_end   = 25.0; // fully faded when closer than this

	// Fade out as distance decreases
	float camera_proximity_alpha = clamp((linear_distance-5.0)/5.0,0.0,1.0);

	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	ALPHA = albedo.a * camera_proximity_alpha * alpha_mask * alpha_mask_2;

}