shader_type canvas_item;

const int MAX = 50;

uniform int count;
uniform vec3 angular_positions[MAX]; // xy = UV, z = distance
uniform int tgt_idx = 50;
uniform float scan_progress:hint_range(0.0, 1.0, 0.01)=0.0;

uniform float ping_width = .1;
uniform float MAX_DISTANCE = 50.0;
uniform int PIXEL_RES = 64;


// Tunables
uniform vec3 far_color  = vec3(0.4);
uniform vec3 near_color = vec3(0.2, 0.7, 1.0);

void fragment() {
    // Pixelated UV
    vec2 uv = floor(UV * float(PIXEL_RES)) / float(PIXEL_RES);

    vec3 col = vec3(0.0);
    float alpha = 0.0;

    for (int i = 0; i < MAX; i++) {
        if (i >= count) break;

        vec2 ping_uv = angular_positions[i].xy;
        float dist   = angular_positions[i].z;

        float d = length(uv - ping_uv);

        // -------- Distance phase weights --------
        float far_w  = smoothstep(10., 20., dist);
        float near_w = 1.0 - smoothstep(3.0, 6.0, dist);
        float mid_w  = 1.0 - far_w - near_w;

        // -------- Radius per phase --------
        float far_radius  = ping_width * 3.0;
        float mid_radius  = ping_width * 0.7;
        float near_radius = ping_width * 1.;

        float radius =
            far_radius  * far_w +
            mid_radius  * mid_w +
            near_radius * near_w;

        // -------- Falloff per phase --------
        float far_fall  = pow(clamp(1.0 - d / radius, 0.0, 1.0), 0.25);
        float mid_fall  = pow(clamp(1.0 - d / radius, 0.0, 1.0), 0.6);
        float near_fall = clamp(1.0 - d / radius, 0.0, 1.0);

        float radial =
            far_fall  * far_w +
            mid_fall  * mid_w +
            near_fall * near_w;

        // -------- Color blend --------
        vec3 color =
            far_color  * far_w +
            near_color * (mid_w + near_w);

        // -------- Opacity control --------
        float far_alpha  = 0.25;
        float mid_alpha  = 1.0;
        float near_alpha = 1.0;

        float opacity =
            far_alpha  * far_w +
            mid_alpha  * mid_w +
            near_alpha * near_w;

        // -------- Subtle near glow --------
        float glow = near_w * pow(radial, 0.3) * 0.4;

        float strength = (radial * opacity) + glow;

		if(d<ping_width*1.5 && d>ping_width*1.3 && dist<5. && tgt_idx!=i){
			alpha=.6;
			col = vec3(0.3,0.3,0.4);
		}
		if(tgt_idx==i)
		{
			if(d<ping_width*1.5-(scan_progress/80.) && d>ping_width*1.3-(scan_progress/16.0) && dist<5.)
			{
				col = mix(vec3(0.1,0.8,0.4),vec3(0.5,1.0,0.9),scan_progress);
				alpha=mix(0.6,1.0,scan_progress);
			}
		}
        col += color * strength;
        alpha = max(alpha, strength);
    }

    COLOR = vec4(col, alpha);
}
