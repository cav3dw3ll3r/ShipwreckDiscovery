shader_type spatial;
render_mode unshaded;

// Standard Albedo
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;
uniform sampler2D texture_normal : hint_normal;
// Caustic Uniforms
uniform sampler2D caustic_texture : hint_default_black;
uniform float caustic_scale = 0.5;
uniform vec2 caustic_speed = vec2(0.02, 0.02);
uniform float caustic_strength = 0.8;
uniform vec3 caustic_tint : source_color = vec3(0.8, 0.9, 1.0);

// Global Darkening Uniforms
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec3 shadow_color : source_color = vec3(0.05, 0.05, 0.1); // Slight blue tint for depth

// Subtle bloom-friendly emission
uniform float caustic_glow_strength : hint_range(0.0, 2.0) = 0.15;
uniform float caustic_glow_softness : hint_range(0.1, 4.0) = 0.8;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // Removed abs() so we can distinguish between up and down
    world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
    // 1. Standard Albedo Mapping
    vec4 albedo_tex = texture(texture_albedo, UV);
    vec3 final_color = albedo.rgb * albedo_tex.rgb;

    // Normalize for consistent math regardless of object scale
    vec3 n_norm = normalize(world_normal);

    // 2. Global Darkening (Facing Down)
    // clamp(-n_norm.y) isolates surfaces pointing towards -Y
    float down_mask = clamp(-n_norm.y, 0.0, 1.0);
    float shadow_factor = pow(down_mask, 2.0) * shadow_strength;
    final_color = mix(final_color, shadow_color, shadow_factor);

    // 3. Double-Scroll Triplanar UVs
    vec2 uv1 = world_pos.xz * caustic_scale + (TIME * caustic_speed);
    vec2 uv2 = world_pos.xz * (caustic_scale * 0.8) - (TIME * caustic_speed * 0.7);

    float mask1 = texture(caustic_texture, uv1).r;
    float mask2 = texture(caustic_texture, uv2).r;
    float final_mask = mask1 * mask2;

    // 4. Caustic Projection (Facing Up)
    // clamp(n_norm.y) ensures caustics only hit the top, preventing "bottom-up" projection
    float top_blend = pow(clamp(n_norm.y, 0.0, 1.0), 2.0);

    // Apply Caustics to the darkened base
    final_color += (final_mask * caustic_strength * caustic_tint) * top_blend;

    // 5. Final Output
    ALBEDO = final_color;

    // Soft glow logic
    float caustic_term = clamp(final_mask * top_blend, 0.0, 1.0);
    float glow_mask = pow(caustic_term, caustic_glow_softness);
    vec3 glow = caustic_tint * (caustic_strength * caustic_glow_strength) * glow_mask;
    
    EMISSION = glow;
	NORMAL_MAP=texture(texture_normal,UV).rgb;
    ALPHA = albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = 0.9;
}
