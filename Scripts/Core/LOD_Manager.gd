extends XRCamera3D
class_name LOD_Manager
# leftover bad architecture (DON'T REFACTOR UNLESS I TELL YOU TO!!!)
@onready var undersea_PP = $UnderseaProcessing

## Seconds between LOD evaluations (depth + optional distance axes).
@export var tick_interval: float = 1.0 / 13.0
## Near / mid distance split (m). Below x => LOD 0, below y => LOD 1, else LOD 2.
@export var boat_distance_thresholds: Vector2 = Vector2(15.0, 40.0)
@export var wreck_distance_thresholds: Vector2 = Vector2(20.0, 60.0)

const GROUP_BOAT_LOD := "Respawn"
const GROUP_WRECK_LOD := "Anchor"

var time_elapsed: float = 0.0
var submersion_level: int = 0
var boat_lod_level: int = -1
var wreck_lod_level: int = -1
var last_player_LOD_origin: Vector3 = Vector3.ZERO

signal submersion_level_changed(new_level: int)
signal boat_lod_changed(new_level: int)
signal wreck_lod_changed(new_level: int)

func _ready() -> void:
	add_to_group("LOD_Manager")
	# First evaluation so subscribers get initial levels without waiting for a tick.
	call_deferred("_emit_initial_lod")


func _emit_initial_lod() -> void:
	process_LOD(true)


func _boat_lod_node() -> Node3D:
	var n := get_tree().get_first_node_in_group(GROUP_BOAT_LOD)
	return n as Node3D if n is Node3D else null


func _wreck_lod_node() -> Node3D:
	var n := get_tree().get_first_node_in_group(GROUP_WRECK_LOD)
	return n as Node3D if n is Node3D else null


## Boat distance LOD runs when a Respawn node exists (first in group).
func is_boat_lod_active() -> bool:
	return is_instance_valid(_boat_lod_node())


## Wreck distance LOD runs when an Anchor node exists (first in group).
func is_wreck_lod_active() -> bool:
	return is_instance_valid(_wreck_lod_node())


func process_LOD(force_emit := false) -> void:
	var new_submersion_level: int = calculate_submersion_index()
	if force_emit or new_submersion_level != submersion_level:
		submersion_level = new_submersion_level
		submersion_level_changed.emit(submersion_level)

	var cam_pos: Vector3 = global_position

	var boat_node := _boat_lod_node()
	if is_instance_valid(boat_node):
		var d_boat: float = cam_pos.distance_to(boat_node.global_position)
		var new_boat: int = _compute_distance_lod(d_boat, boat_distance_thresholds)
		if force_emit or new_boat != boat_lod_level:
			boat_lod_level = new_boat
			boat_lod_changed.emit(boat_lod_level)

	var wreck_node := _wreck_lod_node()
	if is_instance_valid(wreck_node):
		var d_wreck: float = cam_pos.distance_to(wreck_node.global_position)
		var new_wreck: int = _compute_distance_lod(d_wreck, wreck_distance_thresholds)
		if force_emit or new_wreck != wreck_lod_level:
			wreck_lod_level = new_wreck
			wreck_lod_changed.emit(wreck_lod_level)


func _compute_distance_lod(distance: float, thresholds: Vector2) -> int:
	if distance < thresholds.x:
		return 0
	if distance < thresholds.y:
		return 1
	return 2


# Submersion indices:
# 	- 0 | The player is above water
# 	- 1 | The player is between the water and -10m
# 	- 2 | The player is below -10m
func calculate_submersion_index() -> int:
	var is_submerged = undersea_PP.submerged
	if not is_submerged:
		return 0
	var height = global_position.y
	if height > -20. && height < -10.:
		return 2
	if height > -10.:
		return 1
	return 3


func _process(delta: float) -> void:
	time_elapsed += delta
	if time_elapsed > tick_interval:
		process_LOD(false)
		time_elapsed -= tick_interval
