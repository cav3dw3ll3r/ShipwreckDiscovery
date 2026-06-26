shader_type sky;

group_uniforms Water_Colors;
uniform vec4 deep_color : source_color = vec4(0.01, 0.03, 0.07, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.02, 0.12, 0.22, 1.0);
uniform vec4 ray_color : source_color = vec4(0.35, 0.65, 0.85, 1.0);

group_uniforms Ray_Settings;
uniform float ray_speed : hint_range(0.1, 3.0) = 0.6;
uniform float ray_density : hint_range(1.0, 10.0) = 4.0;
uniform float ray_brightness : hint_range(0.1, 3.0) = 1.2;

void sky() {
    vec3 dir = EYEDIR;
    
    // 1. Smooth, global background gradient (Infinite Deep Void)
    // Map Y from [-1, 1] to [0, 1] softly
    float vertical_gradient = smoothstep(-0.6, 0.8, dir.y);
    vec3 final_color = mix(deep_color.rgb, shallow_color.rgb, vertical_gradient);
    
    // 2. Continuous God Ray Generation
    // We use the raw 3D direction vector coordinates to eliminate texturing seams
    float t = TIME * ray_speed;
    
    // Create soft, shifting coordinate distortions using large, overlapping waves
    float distort_x = sin(dir.x * 2.0 + t) * 0.15;
    float distort_z = cos(dir.z * 2.0 + t * 1.2) * 0.15;
    
    // Combine horizontal coordinates with our time-based distortions
    float ray_coord1 = (dir.x + distort_x) * ray_density;
    float ray_coord2 = (dir.z + distort_z) * ray_density * 1.3;
    
    // Generate broad, overlapping columns of light
    float ray_pattern1 = sin(ray_coord1 + t) * cos(ray_coord2 - t * 0.5);
    float ray_pattern2 = cos(ray_coord1 * 0.7 - t * 0.8) * sin(ray_coord2 * 1.2 + t);
    
    // Merge patterns and normalize from [-1, 1] to a safe [0, 1] range
    float combined_rays = (ray_pattern1 + ray_pattern2) * 0.25 + 0.5;
    
    // 3. Soften and Shape the Rays
    // A lower exponent power gives us soft, voluptuous volumetric shafts instead of sharp lines
    float soft_rays = pow(combined_rays, 2.5) * ray_brightness;
    
    // Restrict the rays so they primarily beam down from above and melt away into the deep
    float ray_mask = smoothstep(-0.3, 0.5, dir.y);
    soft_rays *= ray_mask;
    
    // 4. Final Composition
    final_color += ray_color.rgb * soft_rays;
    
    COLOR = final_color;
}