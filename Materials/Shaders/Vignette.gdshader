shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

// Distances in physical meters from the camera lens
uniform float progress = 0.5;
uniform float clear_distance : hint_range(0.0, 1.0) = 0.1;  // Distance where mask is fully transparent
uniform float opaque_distance : hint_range(0.01, 2.0) = 10.; // Distance where mask is solid color
uniform vec3 vignette_color : source_color = vec3(0.0);

void fragment() {
    // VERTEX is the pixel's position relative to the camera.
    // Use only camera-space Z so lateral X/Y offset does not affect the vignette.
    float dist_to_camera = abs(VERTEX.z);

    // Smoothly blend based on that physical distance.
    // If dist_to_camera is at or below clear_distance, vignette is 0.0.
    // If dist_to_camera is at or above opaque_distance, vignette is 1.0.
    float vignette = smoothstep(opaque_distance*progress, clear_distance*progress, dist_to_camera);

    ALBEDO = vignette_color;
    ALPHA = vignette;
    
    // Performance saver: instantly discard completely clear pixels to claw back GPU time
    if (ALPHA < 0.01) {
        discard;
    }
}