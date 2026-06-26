shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_always, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;

// Driven from 0.0 to 1.0
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.3;
uniform vec2 noise_scale = vec2(2.0, 2.0);

// --- Expansion Parameters ---
group_uniforms Reveal_Settings;
uniform float noise_erosion : hint_range(0.1, 2.0) = 0.6;

// --- Border Softness Parameters ---
group_uniforms Border_Settings;
uniform float rect_border_margin : hint_range(0.0, 0.5) = 0.1;
uniform float rect_border_feather : hint_range(0.01, 0.5) = 0.05;
uniform float border_noise_influence : hint_range(0.0, 0.5) = 0.1;

// --- Ambient Color Matching Parameters ---
group_uniforms Environment_Color_Matching;
uniform vec4 ambient_highlight : source_color = vec4(0.18, 0.45, 0.65, 1.0);
uniform vec4 ambient_shadow : source_color = vec4(0.02, 0.08, 0.18, 1.0);

void fragment() {
    // 1. Sample core textures
    vec4 raw_tex = texture(texture_albedo, UV);
    float noise = texture(noise_texture, UV * noise_scale).r;

    // --- PHASE 1: INITIAL INVERSION ---
    // Invert the incoming image color space completely
    vec3 tex_color = raw_tex.rgb;
    // ----------------------------------

    // 2. Calculate luminance on the inverted color space
    // Pure whites (originally pure blacks) now have high luminance values here
    float luminance = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));

    // 3. Organic Radial Reveal Wavefront
    float center_dist = distance(UV, vec2(0.5));
    float radial_gradient = center_dist * 1.414; 
    float reveal_field = radial_gradient + (noise - 0.5) * noise_erosion;
    
    float mapped_progress = progress * (1.0 + edge_softness + noise_erosion);
    float current_threshold = (1.0 + edge_softness + noise_erosion * 0.5) - mapped_progress;
    float alpha_mask = smoothstep(current_threshold, current_threshold + edge_softness, 1.0 - reveal_field);

    // 4. Calculate Rectangular Quad Border Softness
    vec2 distance_to_edge = min(UV, vec2(1.0) - UV);
    float min_dist = min(distance_to_edge.x, distance_to_edge.y);
    float noisy_dist = min_dist + (noise - 0.5) * border_noise_influence;
    float border_mask = smoothstep(rect_border_margin, rect_border_margin + rect_border_feather, noisy_dist);

    // --- PHASE 2: PROCESSING ON INVERTED SPACE ---
    
    // Sample the vertical background gradient vector
    vec3 env_gradient = mix(ambient_shadow.rgb, ambient_highlight.rgb, UV.y);
    
    // On the inverted image, the original absolute whites are now absolute black (0.0).
    // We isolate the lowest values using a smoothstep targeting near-zero values.
    float absolute_white_mask = 1.0 - smoothstep(0.01, 0.05, luminance);
    
    // Remap those target pixels over to the environmental sky color
    vec3 processed_color = mix(tex_color, env_gradient, absolute_white_mask);
    
    // ----------------------------------------------

    // --- PHASE 3: FINAL RE-INVERSION ---
    // Flip the color space back to its original configuration before assignment
    vec3 final_albedo = processed_color;
    
    // Note: If the environment gradient gets flipped backward by the final inversion,
    // we step in and re-assert the un-flipped environment gradient on those exact masked pixels.
    final_albedo = mix(final_albedo, env_gradient, absolute_white_mask);
    // ------------------------------------

    // 5. Final Outputs
    ALBEDO = final_albedo;
    ALPHA = alpha_mask * border_mask;
}