extends MultiMeshInstance3D
class_name MultiProp

func _ready():
	var sources: Array[Node3D] = []

	for child in get_children():
		if child is Node3D:
			sources.append(child)

	var count := sources.size()
	if count == 0:
		return

	multimesh.instance_count = count

	for i in count:
		multimesh.set_instance_transform(i, sources[i].global_transform)
		sources[i].queue_free()
