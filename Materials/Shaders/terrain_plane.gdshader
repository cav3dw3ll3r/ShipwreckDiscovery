shader_type spatial;
render_mode unshaded;

// Top-down (world XZ) albedo: tile_scale controls repeat in world units
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;
uniform sampler2D texture_normal : hint_normal;
uniform float tile_scale = 0.1;

// Noise: sample at large world scale, use to warp UVs and slightly vary tone (reduces grid)
uniform sampler2D tiling_breakup_noise : hint_default_white;
uniform float breakup_coord_scale = 0.08;
uniform float breakup_uv_strength = 0.12;
uniform float breakup_tint_strength : hint_range(0.0, 0.35) = 0.1;

// Caustics (match wreck_chunk.gdshader)
uniform sampler2D caustic_texture : hint_default_black;
uniform float caustic_scale = 0.5;
uniform vec2 caustic_speed = vec2(0.02, 0.02);
uniform float caustic_strength = 0.8;
uniform vec3 caustic_tint : source_color = vec3(0.8, 0.9, 1.0);

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec3 shadow_color : source_color = vec3(0.05, 0.05, 0.1);

uniform float caustic_glow_strength : hint_range(0.0, 2.0) = 0.15;
uniform float caustic_glow_softness : hint_range(0.1, 4.0) = 0.8;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n_norm = normalize(world_normal);

	// World XZ, projected downward: base tiled UVs + multi-sample noise warp
	vec2 w = world_pos.xz * breakup_coord_scale;
	float n0 = texture(tiling_breakup_noise, w).r;
	float n1 = texture(tiling_breakup_noise, w * 1.95 + vec2(17.3, 3.1)).g;
	float n2 = texture(tiling_breakup_noise, w * 0.47 + vec2(5.7, 22.0)).b;

	vec2 uv_warp = vec2(n0, n1) * 2.0 - 1.0;
	uv_warp += (n2 * 2.0 - 1.0) * 0.35;
	vec2 albedo_uv = world_pos.xz * tile_scale + uv_warp * breakup_uv_strength;

	vec4 albedo_tex = texture(texture_albedo, albedo_uv);
	float tint = mix(1.0, n0 * 0.5 + n1 * 0.5, breakup_tint_strength);
	vec3 final_color = albedo.rgb * albedo_tex.rgb * tint;

	// Facing down: global darkening (same as wreck chunk)
	float down_mask = clamp(-n_norm.y, 0.0, 1.0);
	float shadow_factor = pow(down_mask, 2.0) * shadow_strength;
	final_color = mix(final_color, shadow_color, shadow_factor);

	// Double-scroll caustics (from wreck_chunk)
	vec2 cuv1 = world_pos.xz * caustic_scale + (TIME * caustic_speed);
	vec2 cuv2 = world_pos.xz * (caustic_scale * 0.8) - (TIME * caustic_speed * 0.7);
	float mask1 = texture(caustic_texture, cuv1).r;
	float mask2 = texture(caustic_texture, cuv2).r;
	float final_mask = mask1 * mask2;

	float top_blend = pow(clamp(n_norm.y, 0.0, 1.0), 2.0);
	final_color += (final_mask * caustic_strength * caustic_tint) * top_blend;

	ALBEDO = final_color;

	float caustic_term = clamp(final_mask * top_blend, 0.0, 1.0);
	float glow_mask = pow(caustic_term, caustic_glow_softness);
	vec3 glow = caustic_tint * (caustic_strength * caustic_glow_strength) * glow_mask;
	EMISSION = glow;

	NORMAL_MAP = texture(texture_normal, albedo_uv).rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.9;
}
