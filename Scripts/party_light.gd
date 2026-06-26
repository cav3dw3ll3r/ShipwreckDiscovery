extends MeshInstance3D

@export var scaleChanges = true

func _ready() -> void:
	# Randomize the scale
	if(scaleChanges):
		var scale_factor = randf_range(0.1, 10.0)
		scale = Vector3.ONE * scale_factor

	# Create a new random albedo color
	var random_color = Color(randf(),randf(),randf())

	# Create a new StandardMaterial3D and assign the color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = random_color

	# Assign the material to the mesh
	set_surface_override_material(0, mat)
