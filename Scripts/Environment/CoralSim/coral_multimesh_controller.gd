extends Node3D
class_name CoralMultiMeshController

@export_node_path("MultiMeshInstance3D") var staghorn_baby_path: NodePath = ^"StaghornBaby"
@export_node_path("MultiMeshInstance3D") var staghorn_growing_path: NodePath = ^"StaghornGrowing"
@export_node_path("MultiMeshInstance3D") var staghorn_pristine_path: NodePath = ^"StaghornPristine"


func refresh_from_session(corals: Dictionary) -> void:
	var baby_xforms: Array[Transform3D] = []
	var growing_xforms: Array[Transform3D] = []
	var pristine_xforms: Array[Transform3D] = []

	for coral_data in corals.values():
		if int(coral_data.get("type", -1)) != CoralData.CoralType.STAGHORN:
			continue

		var biomass: float = coral_data.get("biomass", 0.0)
		var stage_key := _stage_key_for_biomass(biomass)
		var stage_dict: Dictionary = coral_data.get(stage_key, {})
		var world_xf := _build_world_transform(coral_data, stage_dict)

		if biomass < 30.0:
			baby_xforms.append(world_xf)
		elif biomass < 85.0:
			growing_xforms.append(world_xf)
		else:
			pristine_xforms.append(world_xf)

	_apply_multimesh(staghorn_baby_path, baby_xforms)
	_apply_multimesh(staghorn_growing_path, growing_xforms)
	_apply_multimesh(staghorn_pristine_path, pristine_xforms)


func _stage_key_for_biomass(biomass: float) -> String:
	if biomass < 30.0:
		return "baby"
	if biomass < 85.0:
		return "growing"
	return "pristine"


func _build_world_transform(coral_data: Dictionary, stage_dict: Dictionary) -> Transform3D:
	var global_pos: Vector3 = str_to_var(coral_data["pos"])
	var local_pos: Vector3 = Vector3.ZERO
	var rotation_y: float = 0.0
	var scale_seed: float = 1.0

	if not stage_dict.is_empty():
		local_pos = str_to_var(stage_dict.get("pos", var_to_str(Vector3.ZERO)))
		rotation_y = stage_dict.get("rot", 0.0)
		scale_seed = stage_dict.get("scale", 1.0)

	var basis := Basis.from_euler(Vector3(0.0, rotation_y, 0.0)).scaled(Vector3(scale_seed, scale_seed, scale_seed))
	return Transform3D(basis, global_pos + local_pos)


func _apply_multimesh(path: NodePath, world_xforms: Array[Transform3D]) -> void:
	var mmi := get_node_or_null(path) as MultiMeshInstance3D
	if mmi == null:
		push_warning("CoralMultiMeshController: missing MultiMeshInstance3D at %s" % path)
		return

	if mmi.multimesh == null:
		push_warning("CoralMultiMeshController: no multimesh on %s" % path)
		return

	mmi.multimesh.instance_count = world_xforms.size()
	var inv := mmi.global_transform.affine_inverse()

	for i in world_xforms.size():
		mmi.multimesh.set_instance_transform(i, inv * world_xforms[i])
