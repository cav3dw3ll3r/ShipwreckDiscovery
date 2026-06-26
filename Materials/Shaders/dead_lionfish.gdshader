shader_type spatial;
render_mode blend_mix;
render_mode depth_draw_always;
// --- CAPTURE OUTRO (Zookeeper — tweened 0→1 with cage dissolve) ---
// Whitens toward white and fades ALPHA out; duplicated per-instance during outro.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// --- THE INERTIAL ANCHOR (CPU Summons) ---
uniform vec3 pin_position = vec3(0.0, 0.0, 0.0);
uniform vec3 movement_vector = vec3(0.0, 0.0, 0.0);
uniform float flexibility = 0.5;
uniform float max_radius = 2.0;

// --- THE GRAVITATIONAL ANCHOR ---
uniform vec3 local_gravity_dir = vec3(0.0, -1.0, 0.0); 
uniform float gravity_strength = 0.3; 

// --- THE VISUAL GLAMOUR ---
uniform sampler2D albedo_texture : source_color; 
uniform sampler2D normal_texture : hint_normal; 
uniform float normal_depth : hint_range(0.0, 16.0) = 1.0; 

// --- THE CONTAINMENT TUBE (Dynamic Instance Variables) ---
uniform float is_in_tube = 0.0; // 0.0 = swimming, 1.0 = captured
uniform vec3 local_tube_origin = vec3(0.0);
uniform vec3 local_tube_axis = vec3(0.0, 1.0, 0.0);
// --- TUBE INSERTION BOUNDARIES ---
uniform float mesh_z_min = -0.3; // The deepest point of the mesh along the axis
uniform float mesh_z_max = 0.3;  // The shallowest point of the mesh along the axis

// 0.0 = Fully out of the tube, 1.0 = Fully squished inside
uniform float insertion_progress : hint_range(0.0, 1.0) = 0.0;

// --- TUBE SETTINGS (Static Material Variables) ---
uniform float tube_radius = 0.1; // Set to actual physical radius

// --- FUNNEL GLAMOUR ---
uniform vec3 funnel_color : source_color = vec3(0.0, 0.8, 1.0); // Cyan energy
uniform float funnel_width = 0.15; // How far the gradient spreads from the threshold
uniform float funnel_energy = 2.0; // Emission strength

// The bridge between vertex and fragment
varying float v_funnel_glow;

void vertex() {
    // --- PHASE 1: RAGDOLL PHYSICS ---
    float dist = length(VERTEX - pin_position);
    float weight = smoothstep(0.0, max_radius, dist);
    
    vec3 drag_offset = movement_vector * weight * flexibility;
    vec3 gravity_offset = local_gravity_dir * gravity_strength * weight;
    
    // The baseline position of our vertex before the tube logic
    vec3 v_rag = VERTEX + drag_offset + gravity_offset;

    // --- PHASE 2: 3D CYLINDER MATH (Option B) ---
    // Ensure axis is a perfect unit vector
    vec3 norm_axis = normalize(local_tube_axis);
    
    // Vector from the 3D tube origin to our jiggling vertex
    vec3 p = v_rag - local_tube_origin;
    
    // Distance along the tube axis
    float z_vert = dot(p, norm_axis); 
    
    // Find the exact 3D point on the center axis closest to this vertex
    vec3 closest_axis_point = local_tube_origin + (norm_axis * z_vert);
    
    // Vector pointing directly outward from the center axis to the vertex
    vec3 radial_vec = v_rag - closest_axis_point;
    float r_len = length(radial_vec);

    // --- PHASE 4: RECONSTRUCTION ---
    vec3 r_dir = radial_vec / (r_len + 0.0001); 
    
    // THE FIX: Clamp the radius so it never exceeds the tube, 
    // but leave inner vertices completely alone.
    float r_final = min(r_len, tube_radius); 
    
    vec3 squished_pos = local_tube_origin + (norm_axis * z_vert) + (r_dir * r_final);

    // Example logic to apply the squish progressively along the axis
    // If the vertex's Z position is deeper than the insertion opening, squish it. 
    // Otherwise, leave it as a ragdoll.
    float local_insertion_threshold = mix(mesh_z_max, mesh_z_min, insertion_progress);
	float is_inside = step(local_insertion_threshold, z_vert);

	// THE FUNNEL MATH: Calculate absolute distance from this specific vertex to the moving threshold
	float dist_to_threshold = abs(z_vert - local_insertion_threshold);

	// smoothstep() creates a smooth 0.0 to 1.0 curve. 
	// We invert it (1.0 - x) so the glow is strongest (1.0) exactly AT the threshold, 
	// and fades to 0.0 as it reaches the funnel_width distance.
	v_funnel_glow = 1.0 - smoothstep(0.0, funnel_width, dist_to_threshold);

	VERTEX = mix(v_rag, squished_pos, is_inside);
}

void fragment() {
    vec4 albedo_tex = texture(albedo_texture, UV);

    vec3 base_color = albedo_tex.rgb;
    vec3 with_funnel = mix(base_color, funnel_color, v_funnel_glow);

    vec3 whitened = mix(with_funnel, vec3(1.0), progress);
    ALBEDO = whitened;

    // Die down emission as we vanish so the corpse doesn’t bloom after whitening
    EMISSION = funnel_color * v_funnel_glow * funnel_energy * (1.0 - progress);

    NORMAL_MAP = texture(normal_texture, UV).rgb;
    NORMAL_MAP_DEPTH = normal_depth;

    ALPHA = 1.0 - progress;
}