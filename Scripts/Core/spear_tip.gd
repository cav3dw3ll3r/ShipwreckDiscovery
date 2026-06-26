extends Node3D

## [project] 3d_physics/layer_6 = "Damage Events"
const DAMAGE_EVENTS_LAYER: int = 1

const ray_length: float = 0.2
const max_report_distance: float = 1.0
const VEL_EPS: float = 1.0e-5

## Skip ray hits against this spear (and nested) [RigidBody3D] parents.
@export var kill_prefab:PackedScene
@export var exclude_ancestor_rigidbodies: bool = true
@export_group("Kill Gating")
## Minimum forward speed along spear local +Y (tip direction) at the ray origin — not total speed.
@export var min_tip_thrust_speed_mps: float = 1.0
@export var min_thrust_axis_dot: float = 0.9
@export var min_center_facing_dot: float = 0.85
@export_group("Haptics")
## Weak haptics when the ray reports a hit, but `confirm_hit` decides it is not a kill.
@export var hit_haptic_weak_amplitude: float = 0.18
@export var hit_haptic_weak_duration: float = 0.05
## Strong haptics when `confirm_hit` succeeds (kill confirmed).
@export var hit_haptic_amplitude: float = 0.35
@export var hit_haptic_duration: float = 0.07

@onready var spear=get_node("../")

var _left_controller: XRController3D
var _right_controller: XRController3D
var is_probing:bool = true
var _has_prev_probe_pos: bool = false
var _prev_probe_world_pos: Vector3 = Vector3.ZERO
var _probe_velocity_world: Vector3 = Vector3.ZERO
var _probe_speed_mps: float = 0.0

## Kill prefab rooted under Tip; cleared when freed or transferred to zookeeper.
var current_trophy: Node3D = null
var _trophy_exit_callable_by_id: Dictionary = {}

signal on_kill()

func _ready() -> void:
	_cache_player_controllers()


func _physics_process(delta: float) -> void:
	_update_tip_kinematics(delta)
	if is_probing:
		probe_and_report()

## Same world point as [method probe_and_report] ray origin: Tip plus single-hold slide along local +Y.
func _get_probe_reference_world() -> Vector3:
	var p: Vector3 = global_position
	if is_instance_valid(spear) and spear.current_state is SpearSingleHoldState:
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
		# Hit registered, but confirm rejected the kill (e.g. hit but not killed yet).
		_trigger_grab_haptics(hit_haptic_weak_amplitude, hit_haptic_weak_duration)
		return
	_trigger_grab_haptics(hit_haptic_amplitude, hit_haptic_duration)
	place_trophy(pos, payload)
	on_kill.emit()

func clear_spear_trophy_reference_from_transfer() -> void:
	if current_trophy == null:
		return
	if is_instance_valid(current_trophy):
		_disconnect_trophy_exit_clear(current_trophy)
	current_trophy = null


func _disconnect_trophy_exit_clear(node: Node) -> void:
	var id: int = node.get_instance_id()
	var cb: Callable = _trophy_exit_callable_by_id.get(id, Callable())
	if cb.is_valid() and node.tree_exiting.is_connected(cb):
		node.tree_exiting.disconnect(cb)
	_trophy_exit_callable_by_id.erase(id)


func _on_trophy_exiting(bound_node: Node) -> void:
	if current_trophy == bound_node:
		current_trophy = null
	_trophy_exit_callable_by_id.erase(bound_node.get_instance_id())


func place_trophy(hit_world_pos: Vector3, payload: Dictionary) -> void:
	is_probing = false
	var target_kill_prefab: PackedScene = kill_prefab
	var override_kill_prefab: Variant = payload.get("kill_prefab", null)
	if override_kill_prefab is PackedScene:
		target_kill_prefab = override_kill_prefab as PackedScene
	if target_kill_prefab == null:
		return
	var trophy: Node = target_kill_prefab.instantiate()
	if trophy is Node3D:
		_register_trophy_on_tip(trophy as Node3D)
	add_child(trophy)
	if trophy.has_method("apply_trash_instance_payload"):
		trophy.call("apply_trash_instance_payload", payload)
	if trophy is Node3D:
		var n: Node3D = trophy as Node3D
		var victim_xf: Transform3D = payload["victim_world_xform"] as Transform3D
		n.global_transform = victim_xf
		n.global_position += global_position - hit_world_pos
	if trophy.has_method("apply_spear_tube"):
		trophy.call("apply_spear_tube", self, hit_world_pos)


func _register_trophy_on_tip(n: Node3D) -> void:
	if current_trophy != null and is_instance_valid(current_trophy):
		var prev: Node3D = current_trophy
		_disconnect_trophy_exit_clear(prev)
		if prev.is_inside_tree() and prev.get_parent() == self:
			prev.queue_free()
		current_trophy = null

	current_trophy = n
	var cb: Callable = _on_trophy_exiting.bind(n)
	_trophy_exit_callable_by_id[n.get_instance_id()] = cb
	n.tree_exiting.connect(cb)


func _ancestor_rigidbody_rids() -> Array[RID]:
	var out: Array[RID] = []
	var p: Node = get_parent()
	while p:
		if p is RigidBody3D:
			out.append((p as RigidBody3D).get_rid())
		p = p.get_parent()
	return out


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
