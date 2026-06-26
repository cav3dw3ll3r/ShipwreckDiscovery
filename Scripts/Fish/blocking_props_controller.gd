extends MultiMeshInstance3D

@export var spotlight_target:Spotlight_Target
@export var shared_material: Material
@export var randomize_scale:bool = true
@export var scale_min:float = 0.9
@export var scale_max:float = 1.1
@export var is_hazard:bool = false
@export var is_targetable: bool = false
@export var target_group_name: StringName = &"hazard"
@export var use_dynamic_placement: bool = false
@export var mesh_center_offset:Vector3
## One-shot spatial SFX when [method confirm_hit] removes an instance (e.g. lionfish crunch at victim).
@export var kill_confirm_audio: AudioStream
var transforms:Array[Transform3D] = []

func _ready():
	if use_dynamic_placement:
		_reset_dynamic_placement()
		if shared_material and multimesh and multimesh.mesh:
			multimesh.mesh.surface_set_material(0, shared_material)
		_join_target_group_if_needed()
		return

	print("RANDOMIZE SCALES")
	randomize_scales()
	if shared_material and multimesh and multimesh.mesh:
		multimesh.mesh.surface_set_material(0, shared_material)
	rebuild()
	destroy_markers()
	_join_target_group_if_needed()

func destroy_markers():
	for child in get_children():
		if child is Marker3D: child.queue_free()


func _reset_dynamic_placement() -> void:
	visible = false
	transforms.clear()
	if multimesh:
		multimesh.instance_count = 0

	# Dynamic placement owns the rendered instances; remove legacy marker/proxy
	# children so they cannot appear alongside scatter-populated MultiMesh data.
	for child in get_children():
		if child is Node3D:
			child.visible = false
			child.queue_free()

#func _process(_delta):
	#if live_update:
		#rebuild()

func randomize_scales():
	for c in get_children():
		if c is Node3D:
			print("RESCALING")
			c.scale*=randf_range(scale_min,scale_max)

func get_targetable_transforms():
	if transforms.is_empty() and multimesh != null and multimesh.instance_count > 0:
		_sync_transforms_from_multimesh()
	return transforms

func get_spotlight():
	return spotlight_target


func _join_target_group_if_needed() -> void:
	if is_hazard or is_targetable:
		add_to_group(target_group_name)


func can_damage_player() -> bool:
	return is_hazard

func _sync_transforms_from_multimesh() -> void:
	transforms.clear()
	if multimesh == null:
		return
	for i in multimesh.instance_count:
		var local_xf: Transform3D = multimesh.get_instance_transform(i)
		transforms.append(global_transform * local_xf)

## Returns candidate payload only. Instance removal is deferred to [method confirm_hit].
## This version prioritizes the mesh_center_offset (Cyan sphere) for hit detection.
func report_hit(global_hit_pos: Vector3, max_hit_distance: float = 2.0) -> Dictionary:
	if multimesh == null or multimesh.instance_count <= 0:
		return {"ok": false}

	# Transform the world hit into the MultiMeshInstance's local space
	var local_hit: Vector3 = global_transform.affine_inverse() * global_hit_pos
	var max_hit_dist_sq := max_hit_distance * max_hit_distance
	var best_idx := -1
	var best_dist_sq: float = INF

	# Search for the closest instance based on the OFFSET center
	for i in multimesh.instance_count:
		var local_xf: Transform3D = multimesh.get_instance_transform(i)
		
		# Calculate the Cyan Dot position in MultiMesh local space
		# We rotate the offset by the instance's basis so it follows the mesh's orientation
		var cyan_dot_local = local_xf.origin + (local_xf.basis * mesh_center_offset)
		
		var d2 := cyan_dot_local.distance_squared_to(local_hit)
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best_idx = i

	# Distance validation
	if best_idx == -1 or best_dist_sq > max_hit_dist_sq:
		return {"ok": false}

	# Prepare payload for the confirmed target
	var hit_local_xf: Transform3D = multimesh.get_instance_transform(best_idx)
	var victim_world_xform: Transform3D = global_transform * hit_local_xf
	
	# Compute the World-Space position of the Cyan sphere
	var cyan_world_pos: Vector3 = victim_world_xform * mesh_center_offset
	
	# Calculate hit local to the specific victim instance (useful for particle effects/decals)
	var hit_local_on_victim: Vector3 = victim_world_xform.affine_inverse() * global_hit_pos

	return {
		"ok": true,
		"victim_index": best_idx,
		"victim_world_xform": victim_world_xform,
		"victim_center_world": cyan_world_pos, # Now points to the offset center
		"hit_local_on_victim": hit_local_on_victim,
	}

## Finalizes a previously reported hit candidate by removing the selected multimesh instance.
func confirm_hit(hit_payload: Dictionary) -> Dictionary:
	if multimesh == null or multimesh.instance_count <= 0:
		return {"ok": false}
	var victim_index: int = int(hit_payload.get("victim_index", -1))
	if victim_index < 0 or victim_index >= multimesh.instance_count:
		return {"ok": false}
	_play_kill_confirm_at_victim(hit_payload)
	_remove_multimesh_instance(victim_index)
	if is_hazard:
		SignalBus.lionfish_culled.emit(_get_reward_scale_factor(hit_payload))
	return {"ok": true}


func _get_reward_scale_factor(hit_payload: Dictionary) -> float:
	var victim_xform: Transform3D = hit_payload.get("victim_world_xform", Transform3D.IDENTITY)
	var actual_scale := victim_xform.basis.get_scale().length() / sqrt(3.0)
	if scale_max <= scale_min:
		return 1.0
	var normalized_scale := inverse_lerp(scale_min, scale_max, actual_scale)
	return lerpf(0.75, 1.25, clampf(normalized_scale, 0.0, 1.0))

func _remove_multimesh_instance(remove_idx: int) -> void:
	if multimesh == null or multimesh.instance_count <= 0:
		return

	var last_idx := multimesh.instance_count - 1
	if remove_idx < 0 or remove_idx > last_idx:
		return

	if remove_idx != last_idx:
		var last_xf: Transform3D = multimesh.get_instance_transform(last_idx)
		multimesh.set_instance_transform(remove_idx, last_xf)

	multimesh.instance_count = last_idx
	_sync_transforms_from_multimesh()


func _play_kill_confirm_at_victim(hit_payload: Dictionary) -> void:
	if kill_confirm_audio == null:
		return
	var world_pos: Vector3
	if hit_payload.has("victim_center_world"):
		world_pos = hit_payload["victim_center_world"] as Vector3
	elif hit_payload.has("victim_world_xform"):
		world_pos = (hit_payload["victim_world_xform"] as Transform3D).origin
	else:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = kill_confirm_audio
	player.bus = &"SFX"
	player.unit_size = 4.0
	player.max_db = 10.0
	add_child(player)
	player.global_position = world_pos
	player.finished.connect(player.queue_free)
	player.play()


func populate_from_world_transforms(world_xforms: Array[Transform3D]) -> void:
	if multimesh == null:
		push_warning("blocking_props_controller: cannot populate without multimesh mesh.")
		return

	if shared_material and multimesh.mesh:
		multimesh.mesh.surface_set_material(0, shared_material)

	multimesh.instance_count = world_xforms.size()
	visible = not world_xforms.is_empty()
	var inv := global_transform.affine_inverse()
	transforms.clear()

	for i in world_xforms.size():
		multimesh.set_instance_transform(i, inv * world_xforms[i])
		transforms.append(world_xforms[i])


func rebuild():
	var markers: Array[Node3D] = []
	for c in get_children():
		if c is Node3D:
			markers.append(c)

	if markers.is_empty():
		# Baked multimesh prefabs (e.g. lionfish.tscn) have no Marker3D children; use instance transforms.
		if multimesh != null and multimesh.instance_count > 0:
			_sync_transforms_from_multimesh()
			return
		print("MARKERS EMPTY")
		multimesh = null
		return

	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.instance_count=0
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = false
		multimesh.use_custom_data = false

	multimesh.instance_count = markers.size()

	var inv := global_transform.affine_inverse()
	transforms.clear()

	for i in markers.size():
		var t_form = inv*markers[i].global_transform
		# Full world transform for spotlight / debug (matches multimesh instance placement).
		transforms.append(Transform3D(markers[i].global_transform))
		# convert marker world transform → multimesh local
		multimesh.set_instance_transform(
			i,
			t_form
		)
