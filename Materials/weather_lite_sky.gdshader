shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.18, 0.40, 0.70);
uniform vec3 horizon_color : source_color = vec3(0.52, 0.72, 0.95);
uniform vec3 depths_color : source_color = vec3(0.10, 0.26, 0.30);

uniform sampler2D cloud_texture : hint_default_white;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.35;
uniform float cloud_scale : hint_range(0.2, 3.0) = 0.8;
uniform vec2 cloud_speed = vec2(0.002, 0.0);
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.15;
uniform float cloud_brightness : hint_range(0.0, 1.0) = 0.20;
uniform float horizon_softness : hint_range(0.0, 1.0) = 0.12;
uniform float horizon_offset : hint_range(-0.5, 0.5) = 0.08;
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.78);
uniform float sun_intensity : hint_range(0.0, 2.0) = 0.35;
uniform float sun_size : hint_range(0.001, 0.2) = 0.03;
uniform float sun_softness : hint_range(0.001, 0.2) = 0.04;
uniform float sun_height : hint_range(0.0, 1.0) = 0.30;

void sky() {
    float y = EYEDIR.y;
    float shifted_y = y + horizon_offset;
    // Keep sky + clouds anchored to the real horizon.
    float sky_y = max(y, 0.0);
    float sky_mask = sky_y * sky_y;
    vec3 final_color = mix(horizon_color, zenith_color, sky_mask);

    // Single texture sample cloud layer, projected from view direction.
    if (cloud_amount > 0.0 && y > 0.03) {
        vec2 cloud_uv = (EYEDIR.xz / (y + 0.35)) * cloud_scale + TIME * cloud_speed;
        float cloud_tex = texture(cloud_texture, cloud_uv).r;
        float edge0 = 1.0 - cloud_amount - cloud_softness;
        float edge1 = 1.0 - cloud_amount + cloud_softness;
        float cloud_mask = smoothstep(edge0, edge1, cloud_tex);
        cloud_mask *= smoothstep(0.03, 0.35, y);
        final_color += cloud_mask * cloud_brightness;
    }

    // Only the depth layer uses offset, so depths can be pushed down independently.
    float depth_amount = clamp(-shifted_y, 0.0, 1.0);
    depth_amount *= depth_amount;
    vec3 depth_color = mix(horizon_color, depths_color, depth_amount);
    float depth_blend = 1.0 - smoothstep(-horizon_softness, horizon_softness, shifted_y);
    final_color = mix(final_color, depth_color, depth_blend);

    // Cheap sun highlight in +X/+Z direction, above horizon only.
    vec3 sun_dir = normalize(vec3(1.0, sun_height, 1.0));
    float sun_dist = 1.0 - clamp(dot(normalize(EYEDIR), sun_dir), 0.0, 1.0);
    float sun_mask = 1.0 - smoothstep(sun_size, sun_size + sun_softness, sun_dist);
    sun_mask *= smoothstep(0.0, 0.08, y);
    final_color += sun_color * (sun_mask * sun_intensity);

    COLOR = final_color;
}