shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never,depth_test_disabled, blend_add;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;

uniform vec3 hologram_color : source_color = vec3(0.6, 0.9, 1.0);
uniform float alpha = 0.6;

uniform float scanline_density = 400.0;
uniform float scanline_strength = 0.4;

uniform float flicker_strength = 0.15;
uniform float distortion_strength = 0.02;

uniform float fresnel_power = 3.0;
uniform float fresnel_strength = 1.2;

uniform float time_speed = 1.5;

uniform float progress = 1.0;

void vertex()
{
	VERTEX = vec3(VERTEX.x*progress,VERTEX.y,VERTEX.z*progress);
}

void fragment() {
    float t = TIME * time_speed;

    /* --- UV DISTORTION --- */
    float distortion = sin(UV.y * 20.0 + t * 4.0) * distortion_strength;
    vec2 uv = UV + vec2(distortion, 0.0);

    /* --- TEXTURES --- */
    vec4 albedo_sample = texture(albedo_tex, uv);
    vec3 normal_sample = texture(normal_tex, uv).rgb;
    NORMAL_MAP = normal_sample;

    /* --- SCANLINES --- */
    float scan = sin(VERTEX.y * scanline_density);
    scan = mix(1.0, scan, scanline_strength);

    /* --- FLICKER --- */
    float flicker = sin(t * 18.0 + UV.y * 40.0) * 0.5 + 0.5;
    flicker = mix(1.0, flicker, flicker_strength);

    /* --- FRESNEL --- */
    float fresnel = pow(
        1.0 - dot(normalize(NORMAL), normalize(VIEW)),
        fresnel_power
    ) * fresnel_strength;

    /* --- FINAL COLOR --- */
    vec3 color =
        albedo_sample.rgb * hologram_color * scan * flicker +
        hologram_color * fresnel;

    ALBEDO = color;
    ALPHA = albedo_sample.a * alpha * scan * flicker;
}
