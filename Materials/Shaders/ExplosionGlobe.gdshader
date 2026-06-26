shader_type spatial;

render_mode blend_add, cull_back, depth_prepass_alpha;

uniform sampler2D globe_displacement_texture:source_color;
uniform float globe_displacement_amount;
uniform float min_radius = 0.0;
uniform float max_radius = 1.0;
uniform float progress = 0.0;
uniform float lifetime = 1.0;      // total time of the explosion
uniform float sparkle_intensity = 3.0;
uniform vec4 gold_color : source_color = vec4(1.0, 0.84, 0.0,1.0);

void fragment() {
    // Alpha fades over time
    float alpha = 1.0-clamp(sqrt(progress),0.0,1.0);
	vec4 tex = texture(globe_displacement_texture, UV + vec2(sin(TIME*0.1)));
	float mask = tex.r; // use red channel or luminance
	vec4 result_color = mix(gold_color, vec4(1.0), mask);

    // Radial glow from sphere center
    float dist = length(VERTEX.xyz); // distance from local origin

    ALBEDO = result_color.rgb * sparkle_intensity;
    EMISSION = ALBEDO * sparkle_intensity;
    ALPHA = clamp(alpha,0.0,1.0);
}

void vertex()
{
	float scale = mix(min_radius, max_radius, clamp(progress,0.0,1.0));
	float scale_modifier = (texture(globe_displacement_texture,UV+ vec2(sin(TIME*0.1))).r*globe_displacement_amount)+progress;
	VERTEX*=scale*scale_modifier;
}
