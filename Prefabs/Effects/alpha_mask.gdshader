shader_type spatial;

render_mode unshaded, blend_premul_alpha, cull_back, diffuse_lambert_wrap;

uniform sampler2D coin_texture : source_color; // assign your gold coin texture
uniform sampler2D mask_texture: source_color;
uniform sampler2D glimmer_texture: source_color;
uniform float time_speed : hint_range(0.1, 10.0) = 2.0;
uniform float sparkle_intensity : hint_range(0.1, 10.0) = 3.0;

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
    // Animate UVs to make shimmer move
    vec2 uv = UV + vec2(TIME * time_speed, TIME * 0.5 * time_speed);

    // Sample coin texture
    vec4 tex = texture(coin_texture, uv);

    // Use red channel as random sparkle mask
    float mask = step(0.8, tex.r); // tweak threshold for more/less sparkles
	vec4 mask_2 = texture(mask_texture,UV);
	vec4 mask_3 = texture(glimmer_texture,UV+uv*0.2);
    // Gold glitter color
    vec3 color = tex.rgb * sparkle_intensity * mask;
    ALBEDO = color;
    EMISSION = color;
    ALPHA = mask*mask_2.r*mask_3.r;
	if(mask<0.2)
	{
		discard;
	}
}
