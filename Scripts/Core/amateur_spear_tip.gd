extends Node3D

## [project] 3d_physics/layer_6 = "Damage Events"
const DAMAGE_EVENTS_LAYER: int = 1

const ray_length: float = 0.2
const max_report_distance: float = 1.0
const VEL_EPS: float = 1.0e-5

@export var kill_prefab: PackedScene
@export var exclude_ancestor_rigidbodies: bool = true
@export_group("Kill Gating")
@export var min_tip_thrust_speed_mps: float = 1.0
@export var min_thrust_axis_dot: float = 0.9
@export var min_center_facing_dot: float = 0.85
@export_group("Dissolve outro")
@export var dissolve_duration_sec: float = 2.5
@export var dissolve_audio: AudioStream = preload("res://Audio/koiroylers-shine-02-355934.mp3")
@export_group("Haptics")
@export var hit_haptic_weak_amplitude: float = 0.18
@export var hit_haptic_weak_duration: float = 0.05
@export var hit_haptic_amplitude: float = 0.35
@export var hit_haptic_duration: float = 0.07

@onready var spear = get_node("../")

var _left_controller: XRController3D
var _right_controller: XRController3D
var is_probing: bool = true
var _has_prev_probe_pos: bool = false
var _prev_probe_world_pos: Vector3 = Vector3.ZERO
var _probe_velocity_world: Vector3 = Vector3.ZERO
var _probe_speed_mps: float = 0.0

signal on_kill()


func _ready() -> void:
	_cache_player_controllers()


func _physics_process(delta: float) -> void:
	_update_tip_kinematics(delta)
	if is_probing:
		probe_and_report()


func _get_probe_reference_world() -> Vector3:
	var p: Vector3 = global_position
	if is_instance_valid(spear) and spear.is_picked_up():
		p += _shaft_axis_world() * spear.current_slide_pos
	return p


func _shaft_axis_world() -> Vector3:
	return global_transform.basis.y.normalized()


func _update_tip_kinematics(delta: float) -> void:
	if delta <= 0.0:
		_probe_velocity_world = Vector3.ZERO
		_probe_speed_mps = 0.0
		return
	var probe_pos: Vector3 = _get_probe_reference_world()
	if not _has_prev_probe_pos:
		_prev_probe_world_pos = probe_pos
		_has_prev_probe_pos = true
		_probe_velocity_world = Vector3.ZERO
		_probe_speed_mps = 0.0
		return
	_probe_velocity_world = (probe_pos - _prev_probe_world_pos) / delta
	_probe_speed_mps = _probe_velocity_world.length()
	_prev_probe_world_pos = probe_pos


func _probe_forward_speed_mps() -> float:
	return _probe_velocity_world.dot(_shaft_axis_world())


func _is_tip_thrusting_fast_enough() -> bool:
	return _probe_forward_speed_mps() >= min_tip_thrust_speed_mps


func _get_tip_thrust_alignment_dot() -> float:
	if _probe_speed_mps <= VEL_EPS:
		return -1.0
	return _probe_velocity_world.normalized().dot(_shaft_axis_world())


func _passes_tip_thrust_alignment() -> bool:
	return _get_tip_thrust_alignment_dot() >= min_thrust_axis_dot


func _passes_center_facing_rule(victim_center_world: Vector3, tip_world_pos: Vector3) -> bool:
	var to_center: Vector3 = victim_center_world - tip_world_pos
	if to_center.length_squared() <= VEL_EPS:
		return false
	return _shaft_axis_world().dot(to_center.normalized()) >= min_center_facing_dot


func probe_and_report() -> void:
	if Engine.is_editor_hint():
		return
	var world: Variant = get_world_3d()
	if world == null:
		return
	var space: PhysicsDirectSpaceState3D = (world as World3D).direct_space_state
	if space == null:
		return

	var dir: Vector3 = _shaft_axis_world()
	var from: Vector3 = _get_probe_reference_world()
	if not _is_tip_thrusting_fast_enough():
		return
	if not _passes_tip_thrust_alignment():
		return
	if is_zero_approx(dir.length_squared()):
		return
	var to: Vector3 = from + dir * ray_length

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, DAMAGE_EVENTS_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	if not collider is Area3D:
		return
	var area: Area3D = collider as Area3D
	if not area.has_method("report_hit"):
		return
	var pos: Vector3 = hit.get("position", from) as Vector3
	var result: Variant = area.call("report_hit", pos, max_report_distance)
	var hit_ok: bool = result is Dictionary and (result as Dictionary).get("ok", false)
	if not hit_ok:
		return
	var payload: Dictionary = result as Dictionary
	if not payload.has("victim_world_xform"):
		return
	var victim_xf: Transform3D = payload["victim_world_xform"] as Transform3D
	var center_world: Vector3 = payload.get("victim_center_world", victim_xf.origin) as Vector3
	if not _passes_center_facing_rule(center_world, from):
		return
	var confirm_result: Variant = area.call("confirm_hit", payload)
	var confirmed_ok: bool = confirm_result is Dictionary and (confirm_result as Dictionary).get("ok", false)
	if not confirmed_ok:
		_trigger_grab_haptics(hit_haptic_weak_amplitude, hit_haptic_weak_duration)
		return
	_trigger_grab_haptics(hit_haptic_amplitude, hit_haptic_duration)
	var target_kill_prefab: PackedScene = kill_prefab
	var override_kill_prefab: Variant = payload.get("kill_prefab", null)
	if override_kill_prefab is PackedScene:
		target_kill_prefab = override_kill_prefab as PackedScene
	_spawn_dissolving_kill(victim_xf, target_kill_prefab)
	on_kill.emit()


func _spawn_dissolving_kill(victim_xf: Transform3D, prefab: PackedScene = null) -> void:
	var scene_prefab := prefab if prefab != null else kill_prefab
	if scene_prefab == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var trophy: Node = scene_prefab.instantiate()
	if not (trophy is Node3D):
		if is_instance_valid(trophy):
			trophy.queue_free()
		return
	var n := trophy as Node3D
	scene_root.add_child(n)
	n.global_transform = victim_xf
	if trophy.has_method("play_dissolve_outro"):
		trophy.call("play_dissolve_outro", dissolve_duration_sec, dissolve_audio)


func _trigger_grab_haptics(amp: float, dur: float) -> void:
	if not is_instance_valid(_left_controller) and not is_instance_valid(_right_controller):
		_cache_player_controllers()
	if is_instance_valid(_left_controller):
		_left_controller.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)
	if is_instance_valid(_right_controller):
		_right_controller.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)


func _cache_player_controllers() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player_node: Node = players[0]
	var rig_root: Node = player_node.get_parent()
	if rig_root == null:
		return
	_left_controller = rig_root.get_node_or_null("XRController3D_left") as XRController3D
	_right_controller = rig_root.get_node_or_null("XRController3D_right") as XRController3D
