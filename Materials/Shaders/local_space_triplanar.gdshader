shader_type spatial;

uniform sampler2D diffuse_top;
uniform sampler2D diffuse_front;
uniform sampler2D diffuse_side;
uniform sampler2D normal_top;
uniform sampler2D normal_front;
uniform sampler2D normal_side;


void fragment() {
	vec3 final_color = vec3(0.,0.,0.);
	final_color+=
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
