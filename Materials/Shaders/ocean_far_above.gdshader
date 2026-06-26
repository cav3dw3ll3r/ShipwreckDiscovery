shader_type spatial;

// 'unshaded' for Quest performance
// 'cull_front' for back-face rendering (viewing from below)
render_mode unshaded, cull_front, blend_add; // blend_add makes the "sun" pop more

uniform vec4 emerald_surface : source_color = vec4(0.0, 0.8, 0.6, 1.0); // Classic Gulf Green
uniform vec4 sun_glow_color : source_color = vec4(0.8, 1.0, 0.9, 1.0);  // The "hot" center
uniform float clarity_range : hint_range(1.0, 20.0) = 8.0;              // Higher = clearer water
uniform float sun_size : hint_range(0.1, 1.0) = 0.5;                   // Size of the overhead glow

void fragment() {
    // 1. Calculate the view angle relative to 'Up'
    // This creates the "Snell's Window" effect that follows the player
    float dot_view = clamp(dot(NORMAL, VIEW), 0.0, 1.0);

    // 2. The "Panhandle" Gradient
    // We use a high power to keep the 'bright' area directly above the player,
    // simulating how light penetrates shallow, clear water.
    float snell_window = pow(dot_view, clarity_range);

    // 3. Add a "Hot Spot" for the Sun
    // This simulates the sun being visible through the surface
    float sun_spot = pow(dot_view, clarity_range * 2.0) * sun_size;

    // 4. Final Color Assembly
    // Mix from the emerald green to the bright sun glow based on the angle
    vec3 final_color = mix(vec3(0.0), emerald_surface.rgb, snell_window);
    final_color += sun_glow_color.rgb * sun_spot;

    ALBEDO = final_color;

    // 5. Horizon Fade
    // In the Panhandle, the horizon under-water is a murky emerald-grey.
    // We fade the alpha so it blends into your environment fog.
    ALPHA = clamp(snell_window * 2.0, 0.0, 1.0);
}