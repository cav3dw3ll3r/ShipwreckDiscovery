extends Area3D
class_name DamageSpotlight

@export var group_name="hazard"
@export var damage_amount:int = 10
@export var cone_angle: float = 135.0
@export var max_distance: float = 5.0
@export var MAX_TARGETS: int = 5
@export var damage_receiver_collision_mask: int = 32
## Microseconds of transform-scan work per call to update_collider_positions (inner loop only).
@export var scan_budget_usec: int = 500
## 0 = run spotlight scan every physics frame; otherwise cap scan cadence (e.g. 11 matches EntitySpotlight).
@export var scan_tick_hz: float = 11.0
## 0 = refresh the hazard group list every completed scan cycle. >0 limits get_nodes_in_group to about this Hz.
@export var hazard_group_refresh_hz: float = 0.0
## Log once per second the peak update_collider_positions duration (microseconds) for this node.
@export var debug_profile_scan: bool = false

@onready var player = get_tree().get_first_node_in_group("Player")

var shape_pool: Array[CollisionShape3D] = []
var targets_in_light: Dictionary = {}
var current_sender_origin: Vector3 = Vector3.ZERO

## Match Entity_Spotlight scan cadence; damage does not need 72 Hz.
const DAMAGE_TICK_HZ := 11
const SHAPE_REBINDS_PER_PUBLISH := 1

# Time-budgeted state
var _damage_tick_accumulator: float = 0.0
var _scan_tick_accumulator: float = 0.0
var _cursor_entity: int = 0
var _cursor_transform: int = 0
var _cached_entities: Array = []
var _cached_transforms: Array = []
var _cached_st: Spotlight_Target = null
var _candidates: Array[Dictionary] = []

var _last_hazard_group_fetch_msec: int = -1_000_000
var _profile_scan_peak_usec: int = 0
var _profile_log_deadline_msec: int = 0

var _slot_shape_cache: Array[Shape3D] = []
var _slot_transform_cache: Array[Transform3D] = []
var _slot_enabled_cache: PackedByteArray = PackedByteArray()
var _slot_has_transform_cache: PackedByteArray = PackedByteArray()
var _slot_initialized_cache: PackedByteArray = PackedByteArray()
var _slot_pending_shape_cache: Array[Shape3D] = []
var _slot_pending_shape_active: PackedByteArray = PackedByteArray()

func _ready():
	collision_mask = damage_receiver_collision_mask
	body_shape_entered.connect(_on_body_shape_entered)
	area_shape_entered.connect(_on_area_shape_entered)
	body_shape_exited.connect(_on_body_shape_exited)
	area_shape_exited.connect(_on_area_shape_exited)

	for i in range(MAX_TARGETS):
		var col = CollisionShape3D.new()
		col.disabled = true
		col.set_meta("can_damage_player", true)
		add_child(col)
		shape_pool.append(col)
		_slot_shape_cache.append(null)
		_slot_transform_cache.append(Transform3D.IDENTITY)
		_slot_enabled_cache.append(0)
		_slot_has_transform_cache.append(0)
		_slot_initialized_cache.append(0)
		_slot_pending_shape_cache.append(null)
		_slot_pending_shape_active.append(0)
	var dspan := 1.0 / float(DAMAGE_TICK_HZ)
	_damage_tick_accumulator = (float(abs(hash(str(get_path()))) % 997) / 997.0) * dspan
	if scan_tick_hz > 0.0:
		var sspan := 1.0 / scan_tick_hz
		_scan_tick_accumulator = (float(abs(hash(str(get_path()) + "scan")) % 997) / 997.0) * sspan

func _physics_process(delta: float) -> void:
	_scan_tick_accumulator += delta
	var run_scan := scan_tick_hz <= 0.0
	if not run_scan:
		var scan_interval := 1.0 / scan_tick_hz
		if _scan_tick_accumulator >= scan_interval:
			_scan_tick_accumulator -= scan_interval
			run_scan = true
	if run_scan:
		var profile_t0 := Time.get_ticks_usec()
		update_collider_positions()
		if debug_profile_scan:
			var elapsed := Time.get_ticks_usec() - profile_t0
			if elapsed > _profile_scan_peak_usec:
				_profile_scan_peak_usec = elapsed
			var now_msec := Time.get_ticks_msec()
			if now_msec >= _profile_log_deadline_msec:
				if _profile_scan_peak_usec > 0:
					print("[DamageSpotlight] scan peak %d us (path=%s)" % [_profile_scan_peak_usec, str(get_path())])
				_profile_scan_peak_usec = 0
				_profile_log_deadline_msec = now_msec + 1000

	_damage_tick_accumulator += delta
	var damage_interval := 1.0 / float(DAMAGE_TICK_HZ)
	if _damage_tick_accumulator < damage_interval:
		return
	_damage_tick_accumulator -= damage_interval
	_apply_damage_to_targets_in_light()

func _apply_damage_to_targets_in_light() -> void:
	var sender_origin := current_sender_origin
	if sender_origin == Vector3.ZERO:
		if is_instance_valid(player):
			sender_origin = player.global_position
		else:
			sender_origin = global_position
	for body in targets_in_light.keys():
		if not is_instance_valid(body):
			targets_in_light.erase(body)
			continue
		if not _is_target_currently_overlapping(body):
			targets_in_light.erase(body)
			continue
		var receiver := _resolve_damage_receiver(body)
		if receiver != null:
			receiver.take_damage(damage_amount, 10, sender_origin)

func _is_target_currently_overlapping(target: Node) -> bool:
	if target is PhysicsBody3D:
		return get_overlapping_bodies().has(target)
	if target is Area3D:
		return get_overlapping_areas().has(target)
	return false

func _resolve_damage_receiver(body: Node) -> Node:
	if body == null:
		return null
	if body.has_method("take_damage"):
		return body
	for child in body.get_children():
		if child is Node and child.has_method("take_damage"):
			return child
	var parent := body.get_parent()
	if parent != null and parent.has_method("take_damage"):
		return parent
	return null


func _add_damage_target(body: Node) -> void:
	targets_in_light[body] = int(targets_in_light.get(body, 0)) + 1


func _remove_damage_target(body: Node) -> void:
	var count := int(targets_in_light.get(body, 0)) - 1
	if count > 0:
		targets_in_light[body] = count
	else:
		targets_in_light.erase(body)

func get_cone_dist(pos: Vector3) -> float:
	if player == null:
		return -1.0
	var to_target = pos - player.global_position
	var distance = to_target.length()
	if distance > max_distance: return -1.0
	var forward = -player.global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(to_target.normalized()))
	return distance if angle <= cone_angle else -1.0

func _transform_approximately_equal(a: Transform3D, b: Transform3D, epsilon: float = 0.0005) -> bool:
	return a.origin.distance_to(b.origin) <= epsilon \
		and a.basis.x.distance_to(b.basis.x) <= epsilon \
		and a.basis.y.distance_to(b.basis.y) <= epsilon \
		and a.basis.z.distance_to(b.basis.z) <= epsilon

func _candidate_cap() -> int:
	return maxi(MAX_TARGETS, 1)

func _consider_candidate(entry: Dictionary) -> void:
	var cap := _candidate_cap()
	var dist: float = entry["distance"]
	if _candidates.size() < cap:
		_candidates.append(entry)
		return
	var worst_i := 0
	var worst_d: float = _candidates[0]["distance"]
	for i in range(1, _candidates.size()):
		var d: float = _candidates[i]["distance"]
		if d > worst_d:
			worst_d = d
			worst_i = i
	if dist < worst_d:
		_candidates[worst_i] = entry

func _refresh_hazard_entities() -> void:
	if hazard_group_refresh_hz <= 0.0:
		_cached_entities = get_tree().get_nodes_in_group(group_name)
		_last_hazard_group_fetch_msec = Time.get_ticks_msec()
		return
	var interval_msec := int(ceil(1000.0 / hazard_group_refresh_hz))
	var now_msec := Time.get_ticks_msec()
	if _last_hazard_group_fetch_msec < 0 or now_msec - _last_hazard_group_fetch_msec >= interval_msec:
		_cached_entities = get_tree().get_nodes_in_group(group_name)
		_last_hazard_group_fetch_msec = now_msec

func update_collider_positions():
	if player == null:
		return

	var start_time := Time.get_ticks_usec()

	# Finished a full pass: apply shapes, then refresh entity list for next pass
	if _cursor_entity >= _cached_entities.size():
		if not _cached_entities.is_empty():
			if _candidates.size() > 1:
				_candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
			current_sender_origin = Vector3.ZERO
			var shape_budget_remaining := SHAPE_REBINDS_PER_PUBLISH
			for i in range(MAX_TARGETS):
				if shape_budget_remaining <= 0:
					break
				if _slot_pending_shape_active[i] == 0:
					continue
				var pending_shape: Shape3D = _slot_pending_shape_cache[i]
				if pending_shape == null:
					_slot_pending_shape_cache[i] = null
					_slot_pending_shape_active[i] = 0
					continue
				shape_pool[i].shape = pending_shape
				_slot_shape_cache[i] = pending_shape
				_slot_initialized_cache[i] = 1
				_slot_pending_shape_cache[i] = null
				_slot_pending_shape_active[i] = 0
				shape_budget_remaining -= 1
			for i in range(MAX_TARGETS):
				var shape_node = shape_pool[i]
				if i < _candidates.size():
					if i == 0:
						current_sender_origin = _candidates[i]["transform"].origin
					var c = _candidates[i]
					var desired_shape: Shape3D = c["shape"]
					var target_xf: Transform3D = c["transform"]
					target_xf = target_xf.translated_local(c["offset"])
					var rot: Vector3 = c.get("rotation", Vector3.ZERO)
					if rot != Vector3.ZERO:
						var rot_rad: Vector3 = rot * (PI / 180.0)
						target_xf.basis = target_xf.basis * Basis.from_euler(rot_rad)
					target_xf.basis = target_xf.basis.scaled(c["scale"])
					var should_write_shape := _slot_initialized_cache[i] == 0 or _slot_shape_cache[i] != desired_shape
					var should_write_transform := _slot_initialized_cache[i] == 0 \
						or _slot_has_transform_cache[i] == 0 \
						or not _transform_approximately_equal(_slot_transform_cache[i], target_xf)
					var should_enable := _slot_initialized_cache[i] == 0 or _slot_enabled_cache[i] == 0
					if should_write_shape:
						if shape_budget_remaining > 0:
							shape_node.shape = desired_shape
							_slot_shape_cache[i] = desired_shape
							_slot_pending_shape_cache[i] = null
							_slot_pending_shape_active[i] = 0
							shape_budget_remaining -= 1
						else:
							_slot_pending_shape_cache[i] = desired_shape
							_slot_pending_shape_active[i] = 1
					if should_write_transform:
						shape_node.global_transform = target_xf
					if should_enable:
						shape_node.disabled = false
					shape_node.set_meta("can_damage_player", c.get("can_damage_player", true))
					shape_node.set_meta("target_entity", c.get("entity", null))
					if not should_write_shape:
						_slot_shape_cache[i] = desired_shape
					_slot_transform_cache[i] = target_xf
					_slot_enabled_cache[i] = 1
					_slot_has_transform_cache[i] = 1
					_slot_initialized_cache[i] = 1
				else:
					var should_disable := _slot_initialized_cache[i] == 0 or _slot_enabled_cache[i] == 1
					if should_disable:
						shape_node.disabled = true
					shape_node.set_meta("can_damage_player", true)
					if shape_node.has_meta("target_entity"):
						shape_node.remove_meta("target_entity")
					_slot_shape_cache[i] = null
					_slot_enabled_cache[i] = 0
					_slot_has_transform_cache[i] = 0
					_slot_initialized_cache[i] = 1
					_slot_pending_shape_cache[i] = null
					_slot_pending_shape_active[i] = 0
			_candidates.clear()
		_refresh_hazard_entities()
		_cursor_entity = 0
		_cursor_transform = 0
		_cached_transforms.clear()
		_cached_st = null
		return

	if _cached_entities.is_empty():
		for i in range(shape_pool.size()):
			var shape_node = shape_pool[i]
			if _slot_initialized_cache[i] == 0 or _slot_enabled_cache[i] == 1:
				shape_node.disabled = true
			shape_node.set_meta("can_damage_player", true)
			if shape_node.has_meta("target_entity"):
				shape_node.remove_meta("target_entity")
			_slot_shape_cache[i] = null
			_slot_enabled_cache[i] = 0
			_slot_has_transform_cache[i] = 0
			_slot_initialized_cache[i] = 1
			_slot_pending_shape_cache[i] = null
			_slot_pending_shape_active[i] = 0
		return

	# Get current entity
	var entity = _cached_entities[_cursor_entity]
	if not is_instance_valid(entity):
		_cursor_entity += 1
		_cursor_transform = 0
		_cached_transforms.clear()
		_cached_st = null
		return
	if not entity.has_method("get_spotlight") or not entity.has_method("get_targetable_transforms"):
		_cursor_entity += 1
		_cursor_transform = 0
		_cached_transforms.clear()
		_cached_st = null
		return

	# Cache transforms for this entity if needed
	if _cached_st == null:
		_cached_st = entity.get_spotlight()
		if _cached_st == null or _cached_st.shape == null:
			_cursor_entity += 1
			_cursor_transform = 0
			_cached_transforms.clear()
			_cached_st = null
			return
		_cached_transforms = entity.get_targetable_transforms()
		_cursor_transform = 0

	# Process transforms until budget used
	var n := _cached_transforms.size()
	while _cursor_transform < n:
		if Time.get_ticks_usec() - start_time >= scan_budget_usec:
			return

		var xform: Transform3D = _cached_transforms[_cursor_transform]
		_cursor_transform += 1

		var dist := get_cone_dist(xform.origin)
		if dist < 0.0:
			continue

		_consider_candidate({
			"distance": dist,
			"entity": entity,
			"transform": xform,
			"shape": _cached_st.shape,
			"scale": _cached_st.shape_scale if _cached_st.shape_scale != Vector3.ZERO else Vector3.ONE,
			"offset": _cached_st.shape_offset,
			"rotation": _cached_st.shape_rotation,
			"can_damage_player": entity.can_damage_player() if entity.has_method("can_damage_player") else true
		})

	# Finished this entity
	_cursor_entity += 1
	_cursor_transform = 0
	_cached_transforms.clear()
	_cached_st = null

func _shape_node_from_local_shape(local_shape_index: int) -> CollisionShape3D:
	var owner_id := shape_find_owner(local_shape_index)
	if owner_id == -1:
		return null
	return shape_owner_get_owner(owner_id) as CollisionShape3D


func _on_target_shape_entered(body: Node, local_shape_index: int) -> void:
	var shape_node := _shape_node_from_local_shape(local_shape_index)
	if shape_node == null:
		return
	if shape_node.get_meta("can_damage_player", true):
		_add_damage_target(body)
		return

	var entity_variant: Variant = shape_node.get_meta("target_entity", null)
	if entity_variant is Node and is_instance_valid(entity_variant):
		var entity := entity_variant as Node
		if entity.has_method("kick_from_body"):
			entity.call("kick_from_body", body)


func _on_target_shape_exited(body: Node, local_shape_index: int) -> void:
	var shape_node := _shape_node_from_local_shape(local_shape_index)
	if shape_node == null or shape_node.get_meta("can_damage_player", true):
		_remove_damage_target(body)


func _on_body_shape_entered(_body_rid: RID, body: Node3D, _body_shape_index: int, local_shape_index: int) -> void:
	_on_target_shape_entered(body, local_shape_index)


func _on_area_shape_entered(_area_rid: RID, area: Area3D, _area_shape_index: int, local_shape_index: int) -> void:
	_on_target_shape_entered(area, local_shape_index)


func _on_body_shape_exited(_body_rid: RID, body: Node3D, _body_shape_index: int, local_shape_index: int) -> void:
	_on_target_shape_exited(body, local_shape_index)


func _on_area_shape_exited(_area_rid: RID, area: Area3D, _area_shape_index: int, local_shape_index: int) -> void:
	_on_target_shape_exited(area, local_shape_index)

func report_hit(global_hit_pos: Vector3, max_hit_distance: float = 2.0) -> Dictionary:
	var best_owner: Node = null
	var best_dist_sq: float = INF
	var max_hit_dist_sq := max_hit_distance * max_hit_distance

	for entity in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(entity):
			continue
		if not entity.has_method("get_targetable_transforms"):
			continue

		var xforms: Array = entity.get_targetable_transforms()
		for xf in xforms:
			var xform: Transform3D = xf
			var d2 := xform.origin.distance_squared_to(global_hit_pos)
			if d2 < best_dist_sq:
				best_dist_sq = d2
				best_owner = entity

	if best_owner == null or best_dist_sq > max_hit_dist_sq:
		return {"ok": false}

	if best_owner.has_method("report_hit"):
		var owner_hit: Variant = best_owner.report_hit(global_hit_pos, max_hit_distance)
		if owner_hit is Dictionary and (owner_hit as Dictionary).get("ok", false):
			var payload := owner_hit as Dictionary
			payload["owner"] = best_owner
			return payload

	return {"ok": false}

func confirm_hit(hit_payload: Dictionary) -> Dictionary:
	var owner_variant: Variant = hit_payload.get("owner", null)
	if owner_variant == null:
		return {"ok": false}
	var owner := owner_variant as Node
	if owner == null or not is_instance_valid(owner):
		return {"ok": false}
	if not owner.has_method("confirm_hit"):
		return {"ok": false}
	var confirm_result: Variant = owner.call("confirm_hit", hit_payload)
	if confirm_result is Dictionary:
		return confirm_result as Dictionary
	return {"ok": false}
