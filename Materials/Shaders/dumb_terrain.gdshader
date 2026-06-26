shader_type spatial;

uniform sampler2D top_texture : source_color;
uniform sampler2D side_texture : source_color;
uniform sampler2D noise_texture : hint_default_white;

uniform float uv_scale = 1.0;
uniform float triplanar_sharpness = 8.0;
uniform float noise_strength = 0.05;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // Normal needs to be in world space for triplanar to stay put
    world_normal = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // 1. Get a noise value to "wiggle" the UVs
    float noise = texture(noise_texture, world_pos.xz * 0.1).r;
    vec3 shifted_pos = world_pos + (noise * noise_strength);

    // 2. Calculate Blending Weights based on Normal direction
    vec3 weights = pow(world_normal, vec3(triplanar_sharpness));
    weights /= (weights.x + weights.y + weights.z);

    // 3. Project Top Texture (Y-axis)
    vec3 top_col = texture(top_texture, shifted_pos.xz * uv_scale).rgb;

    // 4. Project Side Textures (X and Z axes)
    vec3 side_col_x = texture(side_texture, shifted_pos.zy * uv_scale).rgb;
    vec3 side_col_z = texture(side_texture, shifted_pos.xy * uv_scale).rgb;

    // 5. Mix it all together
    vec3 final_side = (side_col_x * weights.x) + (side_col_z * weights.z);
    vec3 final_color = mix(final_side, top_col, weights.y);

    ALBEDO = final_color;

    // Hardcode these to keep the Quest 3 fast
    ROUGHNESS = 0.8;
    SPECULAR = 0.0;
}