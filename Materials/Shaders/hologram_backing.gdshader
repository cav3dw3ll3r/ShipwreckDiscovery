shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never,depth_test_disabled, blend_add;

uniform vec3 beam_color : source_color = vec3(0.2, 0.8, 1.0);
uniform float intensity = 2.0;

/* Core beam shaping */
const float core_width = 0.8;
uniform float edge_softness = 2.5;

/* Circle cutout */
uniform float aperture_radius = 0.45;   // size of the circle
uniform float aperture_softness = 0.03;  // feather amount

/* Motion */
uniform float scan_density = 120.0;
uniform float scan_strength = 0.4;
uniform float flicker_strength = 0.2;
uniform float time_speed = 1.5;

uniform float progress = 1.;

void fragment() {
    float t = TIME * time_speed;

    /* --- CIRCLE APERTURE MASK --- */
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);

    float aperture = smoothstep(
        aperture_radius,
        aperture_radius - aperture_softness,
        dist
    );

    /* --- RADIAL CORE (horizontal beam center) --- */
    float x = abs(UV.x - 0.5);
    float core = smoothstep(core_width*progress, 0.0, x);
    core = pow(core, edge_softness);

    /* --- VERTICAL SCANS --- */
    float scan = sin((UV.y + t * 0.8) * scan_density);
    scan = mix(1.0, scan, scan_strength);

    /* --- FLICKER --- */
    float flicker = sin(t * 12.0 + UV.y * 30.0) * 0.5 + 0.5;
    flicker = mix(1.0, flicker, flicker_strength);

    /* --- HEIGHT FADE --- */
    float vertical_fade = smoothstep(1.0, 0.0, UV.y);

    float beam = core * scan * flicker * vertical_fade * aperture;

    ALBEDO = beam_color * beam * intensity;
    ALPHA = beam;
}