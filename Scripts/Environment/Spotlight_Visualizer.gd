extends MultiMeshInstance3D

@export var spotlight: EntitySpotlight
@export var mesh_to_render: Mesh

func _ready():
	if mesh_to_render == null:
		push_error("You must assign a mesh_to_render!")
		return

	# Configure the MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_to_render
	mm.instance_count = 0
	multimesh = mm

func _process(delta: float) -> void:
	if spotlight == null:
		return

	var transforms = spotlight.spotlight_transforms
	var count = len(transforms)
	multimesh.instance_count = count

	for i in range(count):
		multimesh.set_instance_transform(i, transforms[i])
