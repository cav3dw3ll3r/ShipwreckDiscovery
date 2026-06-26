extends Node3D
class_name EntitySpotlight

@export var collision_mask := 1
@export var other_subtrees:Array[Node3D]

@onready var player = get_tree().get_first_node_in_group("Player")

# Dictionary keyed by distance to player, containing the transform3d
var spotlight_targets: Array[Spotlight_Target]=[]
var spotlight_transforms:Array[Transform3D]=[]
var _space_state: PhysicsDirectSpaceState3D
var is_locked:bool 

const MAX_SPOTLIGHT_TARGETS = 206
const CONE_ANGLE := 135.0
const CONE_LENGTH := 50.0
const BUDGET_USEC := 500  # 0.5 ms per frame
const TICK_HZ := 11  # Scannables; coprime with 7 and 13 to spread load

var _tick_accumulator: float = 0.0

# Time-budgeted state: spread work across frames
var _cursor_child: int = 0
var _cursor_transform: int = 0
var _cached_transforms: Array[Transform3D] = []
var _cached_target: Spotlight_Target = null
var _candidates: Array[Dictionary] = []

func _ready():
	_space_state = get_world_3d().direct_space_state
	# Desync aquarium species so process_spotlight budget work does not pile on one frame.
	var span := 1.0 / float(TICK_HZ)
	_tick_accumulator = (float(abs(hash(str(get_path()))) % 997) / 997.0) * span

func _process(delta: float) -> void:
	_tick_accumulator += delta
	var interval := 1.0 / float(TICK_HZ)
	while _tick_accumulator >= interval:
		process_spotlight()
		_tick_accumulator -= interval

func get_cone_dist(pos: Vector3, cone_angle: float, length: float) -> float:
	if player == null:
		return -1.0
	var to_target = pos - player.global_position
	var distance = to_target.length()
	if distance > length:
		return -1.0
	var forward = -player.global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(to_target.normalized()))
	if angle <= cone_angle:
		return distance
	else:
		return -1.0

func process_spotlight():
	if player == null:
		return

	var child_count := get_child_count()
	if child_count == 0:
		return

	var start_time := Time.get_ticks_usec()

	# If we finished a full pass last frame: publish and reset
	if _cursor_child >= child_count:
		_candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
		spotlight_transforms.clear()
		spotlight_targets.clear()
		var count := mini(_candidates.size(), MAX_SPOTLIGHT_TARGETS)
		for i in count:
			spotlight_transforms.append(_candidates[i]["transform"])
			spotlight_targets.append(_candidates[i]["target"])
		_candidates.clear()
		_cursor_child = 0
		_cursor_transform = 0
		_cached_transforms.clear()
		_cached_target = null
		return

	# Get current child
	var child = get_child(_cursor_child)
	if not (child is Node3D and child.has_method("get_spotlight")):
		_cursor_child += 1
		_cursor_transform = 0
		_cached_transforms.clear()
		_cached_target = null
		return

	# Cache transforms for this child if needed
	if _cached_target == null:
		_cached_target = child.get_spotlight()
		if _cached_target == null:
			_cursor_child += 1
			_cursor_transform = 0
			_cached_transforms.clear()
			return
		_cached_transforms = child.get_targetable_transforms()
		_cursor_transform = 0

	# Process transforms until budget used
	var n := _cached_transforms.size()
	while _cursor_transform < n:
		if Time.get_ticks_usec() - start_time >= BUDGET_USEC:
			return

		var xform: Transform3D = _cached_transforms[_cursor_transform]
		_cursor_transform += 1

		var distance := get_cone_dist(xform.origin, CONE_ANGLE, CONE_LENGTH)
		if distance < 0.0:
			continue

		_candidates.append({
			"distance": distance,
			"target": _cached_target,
			"transform": xform
		})

	# Finished this child; advance to next
	_cursor_child += 1
	_cursor_transform = 0
	_cached_transforms.clear()
	_cached_target = null
