shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;
uniform vec4 visible_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);

// If your project/driver uses reverse-Z (Godot 4 often does), set this true.
// If comparisons look inverted (visible when they should be hidden), flip this.
uniform bool reverse_z = false;

void fragment() {
    // Sample scene depth (non-linear 0..1 as stored in the depth texture)
    float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;

    // Current fragment depth in the same non-linear clip/texture space
    float my_depth = FRAGCOORD.z;

    // Small epsilon to avoid z-fighting / numerical issues
    float eps = 1e-4;

    bool occluded;
    if (reverse_z) {
        // With reverse-Z, larger depth values mean closer objects.
        occluded = scene_depth > my_depth + eps;
    } else {
        // With normal-Z, smaller depth values mean closer objects.
        occluded = scene_depth < my_depth - eps;
    }

    if (occluded) {
        ALBEDO = visible_color.rgb;
        ALPHA = visible_color.a;
    } else {
        discard;
    }
}
