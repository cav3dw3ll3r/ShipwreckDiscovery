shader_type spatial;

render_mode cull_disabled;
render_mode depth_draw_always;
uniform sampler2D albedo_texture : source_color;
uniform float alpha=1.;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D noise_texture; 
uniform float roughness;
uniform float metallic;

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float explosion_intensity = 3.0;
uniform vec4 glow_color : source_color = vec4(2.0, 0.5, 0.1, 1.0);
uniform float glow_thickness : hint_range(0.0, 0.2) = 0.05;

void vertex() {
	// We sample noise using UVs for consistent fragmentation
	float tex_noise = texture(noise_texture, UV).r;
	
	// By multiplying by progress here, the displacement is strictly 0 at progress 0
	// We use progress * progress (squaring) for a more "explosive" easing curve
	float drive = progress * progress;
	float displacement = tex_noise * drive * explosion_intensity;
	
	VERTEX += NORMAL * displacement;
}

void fragment() {
	// 1. Standard PBR 
	vec4 albedo_tex = texture(albedo_texture, UV);
	ALBEDO = albedo_tex.rgb * albedo_tint.rgb;
	ALPHA = alpha;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// 2. High-Resolution Dissolve
	// Sampling noise in fragment gives us pixel-perfect edges regardless of mesh density
	float noise_val = texture(noise_texture, UV).r;
	
	// We remap the noise so that at progress 0, nothing is discarded.
	// As progress moves from 0 to 1, the "threshold" climbs.
	float threshold = progress;
	float mask = noise_val - threshold;

	// 3. The Glow & Discard
	if (mask < 0.0) {
		discard;
	}

	// The glow only appears when progress > 0
	if (progress > 0.0 && mask < glow_thickness) {
		// Sharpen the glow edge as it vanishes
		float glow_fade = 1.0 - (mask / glow_thickness);
		EMISSION = glow_color.rgb * glow_fade * 5.0;
	}
}