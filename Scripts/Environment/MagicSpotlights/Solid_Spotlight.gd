extends StaticBody3D
class_name SolidClimbableSpotlight

@export var group_name: String = "climbable"
@export var cone_angle: float = 180.0  # unused for collision mode; nearest chunks only
@export var max_distance: float = 40.0  # unused for collision mode; nearest chunks only
@export var MAX_TARGETS: int = 5

@onready var player = get_tree().get_first_node_in_group("Player")

var shape_pool: Array[CollisionShape3D] = []
var _grabs: Dictionary = {} # Active grabs keyed by the pickup node
var _shape_entity: Array = []  # shape_pool index -> entity (chunk) that owns that slot; used to lock grabbed chunks

# XRTools climbable interface compatibility
var press_to_hold: bool = true

signal on_grab(grabs)
signal on_letgo(grabs)

const TICK_HZ := 7  # Coprime with 11 and 13 to spread spotlight load

var _tick_accumulator: float = 0.0

var _slot_shape_cache: Array[Shape3D] = []
var _slot_transform_cache: Array[Transform3D] = []
var _slot_enabled_cache: PackedByteArray = PackedByteArray()
var _slot_has_transform_cache: PackedByteArray = PackedByteArray()
var _slot_initialized_cache: PackedByteArray = PackedByteArray()

func _ready():
	process_priority = 1

	for i in range(MAX_TARGETS):
		var col = CollisionShape3D.new()
		col.disabled = true
		add_child(col)
		shape_pool.append(col)
		_slot_shape_cache.append(null)
		_slot_transform_cache.append(Transform3D.IDENTITY)
		_slot_enabled_cache.append(0)
		_slot_has_transform_cache.append(0)
		_slot_initialized_cache.append(0)
	_shape_entity.resize(MAX_TARGETS)

# --- XRTools Interface Logic ---
func is_xr_class(name: String) -> bool:
	return name == "XRToolsClimbable"

func is_picked_up() -> bool:
	# This object itself is never "held" like a dynamic pickable;
	# returning false matches XRToolsClimbable.gd behavior.
	return false

func can_pick_up(_by: Node3D) -> bool:
	return true

func request_highlight(_from, _on) -> void:
	# Solid spotlight doesn't participate in highlight visuals
	pass

func pick_up(by: Node3D) -> void:
	var best_shape: CollisionShape3D = null
	var min_dist: float = 999.0
	for shape in shape_pool:
		if shape.disabled:
			continue
		var d = by.global_position.distance_to(shape.global_position)
		if d < min_dist:
			min_dist = d
			best_shape = shape

	var point = Node3D.new()
	if best_shape:
		best_shape.add_child(point)
	else:
		add_child(point)

	point.global_transform = by.global_transform
	_grabs[by] = point
	on_grab.emit(_grabs)

func let_go(by: Node3D, _p_lv: Vector3, _p_av: Vector3) -> void:
	var point = _grabs.get(by)
	if is_instance_valid(point):
		point.queue_free()
		_grabs.erase(by)
	on_letgo.emit(_grabs)

func get_grab_handle(by: Node3D) -> Node3D:
	return _grabs.get(by)

# --- The Spotlight Logic ---

func _physics_process(delta: float) -> void:
	_tick_accumulator += delta
	var interval := 1.0 / float(TICK_HZ)
	while _tick_accumulator >= interval:
		update_collider_positions()
		_tick_accumulator -= interval

func get_cone_dist(pos: Vector3, player_pos: Vector3, _forward: Vector3) -> float:
	var to_target = pos - player_pos
	return sqrt(to_target.length_squared())

func _transform_approximately_equal(a: Transform3D, b: Transform3D, epsilon: float = 0.0005) -> bool:
	return a.origin.distance_to(b.origin) <= epsilon \
		and a.basis.x.distance_to(b.basis.x) <= epsilon \
		and a.basis.y.distance_to(b.basis.y) <= epsilon \
		and a.basis.z.distance_to(b.basis.z) <= epsilon

func update_collider_positions():
	if player == null:
		return
	var player_pos = player.global_position
	var player_forward = -player.global_transform.basis.z
	var projectile = get_tree().get_first_node_in_group("Projectile")
	var projectile_pos: Vector3 = Vector3.ZERO
	var has_projectile := projectile != null and is_instance_valid(projectile) and projectile is Node3D
	if has_projectile:
		projectile_pos = (projectile as Node3D).global_position
	var climbable_entities: Array = get_tree().get_nodes_in_group(group_name)
	if climbable_entities.is_empty():
		for i in range(shape_pool.size()):
			var empty_shape = shape_pool[i]
			for child in empty_shape.get_children():
				child.queue_free()
			empty_shape.disabled = true
			_slot_shape_cache[i] = null
			_slot_enabled_cache[i] = 0
			_slot_has_transform_cache[i] = 0
			_slot_initialized_cache[i] = 1
			_shape_entity[i] = null
		return

	var candidates: Array[Dictionary] = []
	for entity in climbable_entities:
		if not entity.has_method("get_spotlight") or not entity.has_method("get_targetable_transforms"):
			continue
		var st: Spotlight_Target = entity.get_spotlight()
		if st == null or st.shape == null:
			continue
		var transforms: Array[Transform3D] = entity.get_targetable_transforms()
		for xform in transforms:
			var candidate_distance := get_cone_dist(xform.origin, player_pos, player_forward)
			if has_projectile:
				candidate_distance = min(candidate_distance, get_cone_dist(xform.origin, projectile_pos, player_forward))
			candidates.append({
				"distance": candidate_distance,
				"transform": xform,
				"shape": st.shape,
				"scale": st.shape_scale if st.shape_scale != Vector3.ZERO else Vector3.ONE,
				"offset": st.shape_offset,
				"rotation": st.shape_rotation,
				"entity": entity
			})

	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var selected_count := mini(MAX_TARGETS, candidates.size())

	for i in range(MAX_TARGETS):
		var shape_node = shape_pool[i]
		if i < selected_count:
			var c = candidates[i]
			var desired_shape: Shape3D = c["shape"]
			var target_xf: Transform3D = c["transform"]
			target_xf = target_xf.translated_local(c["offset"])
			var rot: Vector3 = c.get("rotation", Vector3.ZERO)
			if rot != Vector3.ZERO:
				var rot_rad: Vector3 = rot * (PI / 180.0)
				target_xf.basis = target_xf.basis * Basis.from_euler(rot_rad)
			target_xf.basis = target_xf.basis.scaled(c["scale"])

			if _slot_shape_cache[i] != desired_shape:
				shape_node.shape = desired_shape
			if _slot_has_transform_cache[i] == 0 or not _transform_approximately_equal(_slot_transform_cache[i], target_xf):
				shape_node.global_transform = target_xf
			shape_node.disabled = false
			_slot_shape_cache[i] = desired_shape
			_slot_transform_cache[i] = target_xf
			_slot_enabled_cache[i] = 1
			_slot_has_transform_cache[i] = 1
			_slot_initialized_cache[i] = 1
			_shape_entity[i] = c["entity"]
		else:
			for child in shape_node.get_children():
				child.queue_free()
			shape_node.disabled = true
			_slot_shape_cache[i] = null
			_slot_enabled_cache[i] = 0
			_slot_has_transform_cache[i] = 0
			_slot_initialized_cache[i] = 1
			_shape_entity[i] = null
