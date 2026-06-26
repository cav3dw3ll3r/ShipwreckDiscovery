extends "res://Scripts/Fish/blocking_props_controller.gd"


@export var kill_prefab: PackedScene
@export var kick_distance: float = 0.45
@export var kick_lift: float = 0.08
@export var kick_hit_distance: float = 0.75
@export var sink_speed:float = 0.8
@export var trash_size:float = 0.05

func populate_from_world_transforms(world_xforms: Array[Transform3D]) -> void:
	var scaled_xforms: Array[Transform3D] = []
	scaled_xforms.resize(world_xforms.size())

	for i in world_xforms.size():
		var xf := world_xforms[i]
		xf.basis = _random_can_basis().scaled(Vector3.ONE * trash_size)
		scaled_xforms[i] = xf

	super.populate_from_world_transforms(scaled_xforms)


func _random_can_basis() -> Basis:
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.RIGHT, randf_range(0.0, TAU))
	basis = basis.rotated(Vector3.UP, randf_range(0.0, TAU))
	basis = basis.rotated(Vector3.FORWARD, randf_range(0.0, TAU))
	return basis


func report_hit(global_hit_pos: Vector3, max_hit_distance: float = 2.0) -> Dictionary:
	var payload := super.report_hit(global_hit_pos, max_hit_distance)
	if payload.get("ok", false) and kill_prefab != null:
		payload["kill_prefab"] = kill_prefab
	if payload.get("ok", false):
		_add_trash_appearance_payload(payload)
	return payload


func _add_trash_appearance_payload(payload: Dictionary) -> void:
	if multimesh == null:
		return
	var victim_index: int = int(payload.get("victim_index", -1))
	if victim_index < 0 or victim_index >= multimesh.instance_count:
		return
	payload["trash_appearance_seed"] = float(victim_index + 1)
	payload["trash_instance_index"] = victim_index
	payload["trash_instance_transform"] = multimesh.get_instance_transform(victim_index)
	if multimesh.mesh != null:
		payload["trash_mesh"] = multimesh.mesh
		var source_material := shared_material
		if source_material == null and multimesh.mesh.get_surface_count() > 0:
			source_material = multimesh.mesh.surface_get_material(0)
		if source_material != null:
			payload["trash_source_material"] = source_material


func confirm_hit(hit_payload: Dictionary) -> Dictionary:
	var result := super.confirm_hit(hit_payload)
	if result.get("ok", false):
		SignalBus.trash_picked_up.emit()
	return result


func kick_from_body(body: Node) -> void:
	if body == null or not body is Node3D:
		return
	kick_from_position((body as Node3D).global_position)


func kick_from_position(source_world_pos: Vector3) -> void:
	var payload := super.report_hit(source_world_pos, kick_hit_distance)
	if not payload.get("ok", false):
		return
	var victim_index: int = int(payload.get("victim_index", -1))
	if multimesh == null or victim_index < 0 or victim_index >= multimesh.instance_count:
		return

	var center_world: Vector3 = payload.get("victim_center_world", global_position) as Vector3
	var away := center_world - source_world_pos
	away.y = 0.0
	if away.length_squared() <= 0.0001:
		away = -global_transform.basis.z
	away = away.normalized()

	var local_xf := multimesh.get_instance_transform(victim_index)
	var world_xf := global_transform * local_xf
	world_xf.origin += away * kick_distance + Vector3.UP * kick_lift
	multimesh.set_instance_transform(victim_index, global_transform.affine_inverse() * world_xf)
	_sync_transforms_from_multimesh()
