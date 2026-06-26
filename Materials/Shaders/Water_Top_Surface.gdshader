shader_type spatial;

#include "HeightMapReader.gdshaderinc"

render_mode unshaded,depth_draw_opaque,cull_back; // avoid transparent overdraw

group_uniforms Normals;
uniform sampler2D normal1 : hint_normal;
uniform vec2 normal_scale;
uniform float normal_churn_speed = 0.5;

group_uniforms Colors;
uniform vec3 deep_color = vec3(0.0, 0.37, 0.42);
uniform vec3 shallow_color = vec3(0.0, 0.6, 0.7);

group_uniforms Waves;
uniform float wave_amplitude = 1.0;
uniform float wave_length = 0.1;
uniform float wave_speed = 2.0;
const int wave_count = 3; // lower default
uniform float wave_time = 0.0;

varying vec3 worldPos;
varying vec3 waterPos;

// THE WIZARD's LOCK: Hardcoded, pre-normalized vectors.
// This guarantees the GPU and CPU aren't calculating different vector lengths.
const vec2 wave_directions[3] = vec2[3](
    vec2(0.894427, 0.447213),
    vec2(-0.573462, 0.819231),
    vec2(0.529998, -0.847998)
);

void vertex() {
    worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 pos = worldPos.xz;

    float total_displacement = 0.0;
    float total_displacement_x = 0.0;
    float total_displacement_z = 0.0;
    vec2 dx = vec2(1.0, 0.0);
    vec2 dz = vec2(0.0, 1.0);

    // limit loop to a small safe number by design in shader - keep wave_count low
    int max_waves = min(wave_count, 5);
    for (int i = 0; i < max_waves; i++) {
        // No normalize() call here. We use the pre-calculated constants.
        vec2 dir = wave_directions[i]; 
        
        float freq = (1.0 / max(0.0001, wave_length)) * float(i + 1);
        float phase = wave_time * wave_speed * float(i + 1) * 0.18;
        
        float w = sin(dot(pos, dir) * freq + phase);
        float amp = wave_amplitude / float(i + 1);
        total_displacement += w * amp;
        
        float wx = sin(dot(pos + dx, dir) * freq + phase) * amp;
        float wz = sin(dot(pos + dz, dir) * freq + phase) * amp;
        total_displacement_x += wx;
        total_displacement_z += wz;
    }

    VERTEX.y += total_displacement;
    waterPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // cheap tangent/normal estimate in vertex to avoid heavy per-fragment math
    vec3 tangent_x = vec3(1.0, total_displacement_x - total_displacement, 0.0);
    vec3 tangent_z = vec3(0.0, total_displacement_z - total_displacement, 1.0);
    vec3 n = normalize(cross(tangent_z, tangent_x));
    
    // FIXED: Passed as Local Space to prevent the VR headset "headlight" rotation effect
    NORMAL = n; 
}

// fog by distance only (cheap)
uniform vec3 fog_color = vec3(0.0, 0.8, 0.9);
uniform float fog_density = 0.02; // small by default

void fragment() {
    // single normal sample (low cost)
    vec2 uv1 = UV * normal_scale + vec2(wave_time * normal_churn_speed, 0.0);
    vec3 n1 = texture(normal1, uv1).rgb * 2.0 - 1.0;
    vec3 combined_normal = normalize(n1 + vec3(0.0, 0.0, 0.0)); // keep mostly the baked normal

    // cheaper fresnel (avoid pow())
    float ndotv = max(dot(NORMAL, VIEW), 0.0);
    float fresnel = (1.0 - ndotv);
    fresnel = fresnel * fresnel; // equivalent to pow(x,2) but cheaper

    vec3 base_color = mix(deep_color, shallow_color, fresnel);

    // distance-based fog (cheap)
    float dist = length(waterPos - CAMERA_POSITION_WORLD);
    float fog_factor = 1.0 - exp(-dist * fog_density);
    fog_factor = clamp(fog_factor, 0.0, 1.0);
    vec3 final_color = mix(base_color, fog_color, fog_factor);

    ALBEDO = mix(final_color,deep_color*0.9,combined_normal);
    SPECULAR = 0.25;
    ROUGHNESS = 0.75;
    ALPHA = 1.0;
}