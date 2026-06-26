@tool
extends XRToolsPickable
class_name SpearPickable

## When no [member shaft_rear_stop] node, lower bound = scene rest main Y + this.
@export var min_y_offset_from_start: float = -0.05
## Shrink the upper end so the hand stops this far below the secondary grab's local Y.
@export var max_y_epsilon: float = 0.0
## Optional: explicit rear stop.
@export var shaft_rear_stop: Node3D

@export_group("Physics & Fling")
@export var fling_y_velocity_max: float = 3.0
@export var fling_ramp_duration: float = 0.12
@export var fling_along_local_y: float = 1.0
@export var submerge_at_world_y: float = 0.0
@export var air_gravity_scale: float = 1.0
@export var submerged_gravity_scale: float = 0.15
@export var in_flight_min_speed: float = 0.25
@export var in_flight_reorient_min_speed: float = 0.05

@export_group("Audio")
@export var windup_speed_for_min: float = 0.1
@export var windup_speed_for_max: float = 2.5
@export var windup_min_volume_db: float = -24.0
@export var windup_max_volume_db: float = 2.0
@export var windup_min_pitch_scale: float = 0.85
@export var windup_max_pitch_scale: float = 1.25

@export_group("Inter-hand shaft")
@export var inter_hand_y_flip: float = 1.0
@export var inter_hand_min_separation: float = 0.02
## Set to false so the mesh anchors to the secondary hand (loading hand) while sliding.
@export var inter_hand_anchor_primary_hand: bool = false

@export_group("Lite Grab Hands")
@export var left_lite_grab_point: XRToolsGrabPoint
@export var right_lite_grab_point: XRToolsGrabPoint
@export var left_hand_on_left_point_mesh: Node3D
@export var right_hand_on_left_point_mesh: Node3D
@export var left_hand_on_right_point_mesh: Node3D
@export var right_hand_on_right_point_mesh: Node3D

@export_group("Haptics")
@export var windup_haptic_low_threshold: float = 0.5
@export var windup_haptic_high_threshold: float = 0.95
@export var windup_haptic_low_amplitude: float = 0.25
@export var windup_haptic_low_duration: float = 0.05
@export var windup_haptic_high_amplitude: float = 0.8
@export var windup_haptic_high_duration: float = 0.12
@export var fire_haptic_min_slide: float = 0.5
@export var fire_haptic_min_amplitude: float = 0.2
@export var fire_haptic_max_amplitude: float = 0.9
@export var fire_haptic_min_duration: float = 0.05
@export var fire_haptic_max_duration: float = 0.18

@onready var above_twang: AudioStream = preload("res://Audio/Above_Water_Twang.mp3")
@onready var below_twang: AudioStream = preload("res://Audio/Twang_Submerged.mp3")
@onready var _main_grab: XRToolsGrabPoint = $MainGrabPoint
@onready var _secondary_grab: XRToolsGrabPoint = $SecondaryGrabPoint
@onready var _release_twang_player: AudioStreamPlayer3D = $ReleaseTwangPlayer
@onready var _windup_player: AudioStreamPlayer3D = $WindUpPlayer

var _initial_main_y: float
var _slide_anchors_ready: bool = false
var slide_position: float = 0.0
var _pending_fling_slide: float = -1.0
var _fling_ramp_t: float = 0.0
var _fling_magnitude: float = 0.0
var _fling_w_prev: float = 0.0
var _is_fling_ramping: bool = false
var _fling_dir_world: Vector3 = Vector3.ZERO
var is_in_flight: bool = false
var submerged: bool = false
var _submerge_check_acc: float = 0.0
var _slide_velocity: float = 0.0
var _windup_low_armed: bool = true
var _windup_high_armed: bool = true
var _combo_counts: Dictionary = {}

const SUBMERGE_CHECK_INTERVAL_SEC: float = 0.5
const _WINDUP_REARM_HYSTERESIS: float = 0.05
const _INTER_HAND_ROLL_PAR: float = 0.98
const _InterHandPostAlign: Script = preload("res://Scripts/Player/Spear_InterHandPostAlign.gd")

func _init() -> void:
	process_physics_priority = -90

func _ready() -> void:
	super()
	add_to_group("Projectile")
	if not grabbed.is_connected(_on_grabbed):
		grabbed.connect(_on_grabbed)
	if not released.is_connected(_on_released):
		released.connect(_on_released)
	if not dropped.is_connected(_on_dropped):
		dropped.connect(_on_dropped)
	_sync_lite_grab_hands()
	_initial_main_y = _main_grab.position.y
	if not shaft_rear_stop and has_node("ShaftRearStop"):
		shaft_rear_stop = get_node("ShaftRearStop") as Node3D
	if not Engine.is_editor_hint():
		_update_submersion()
		_reset_windup_audio()
		if not has_node("InterHandPostAlign"):
			var al := _InterHandPostAlign.new() as Node
			al.name = "InterHandPostAlign"
			add_child(al)


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and is_picked_up():
		drop()
	super()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_submerge_check_acc += delta
	if _submerge_check_acc < SUBMERGE_CHECK_INTERVAL_SEC: return
	_submerge_check_acc = 0.0
	_update_submersion()

func _on_collision_with_body(_body:Node):
	is_in_flight=false
	linear_velocity=linear_velocity/2.

func _update_submersion() -> void:
	var is_below: bool = global_position.y < submerge_at_world_y
	gravity_scale = submerged_gravity_scale if is_below else air_gravity_scale
	if submerged != is_below:
		_release_twang_player.stream = below_twang if is_below else above_twang
	submerged = is_below

func pick_up(by: Node3D) -> void:
	_pending_fling_slide = -1.0
	_is_fling_ramping = false
	is_in_flight = false
	_windup_low_armed = true
	_windup_high_armed = true
	_reset_windup_audio()
	
	var is_already_held = is_picked_up()
	var current_pk: XRToolsGrabPoint = _grab_driver.primary.point if (is_already_held and is_instance_valid(_grab_driver) and is_instance_valid(_grab_driver.primary)) else null
	var incoming: XRToolsGrabPoint = _get_grab_point(by, current_pk)
	
	super(by)
	
	if not is_already_held and _is_resolved_point(incoming, _main_grab):
		_main_grab.position.y = _initial_main_y
		if is_instance_valid(_grab_driver) and is_instance_valid(_grab_driver.primary):
			_grab_driver.primary.transform = _main_grab.transform

func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	if not is_picked_up() or not is_instance_valid(_grab_driver): return
	var g: Grab = _grab_driver.get_grab(by)
	if not g: return
	
	var had_two_hands: bool = is_instance_valid(_grab_driver.primary) and is_instance_valid(_grab_driver.secondary)
	var releasing_is_main_point: bool = _is_resolved_point(g.point, _main_grab)
	var slide_snap: float = slide_position
	
	if had_two_hands and releasing_is_main_point:
		_pending_fling_slide = maxf(_pending_fling_slide, slide_snap)
	
	if releasing_is_main_point:
		_play_release_twang(slide_snap)
		_play_release_haptic(slide_snap, by)

	# Transition: If releasing the loading hand, lock the main hand's current slide
	if not releasing_is_main_point and is_instance_valid(_grab_driver.primary):
		_grab_driver.primary.transform = _main_grab.transform

	if releasing_is_main_point and is_instance_valid(_grab_driver.secondary):
		var secondary_by: Node3D = _grab_driver.secondary.by
		super.let_go(secondary_by, Vector3.ZERO, Vector3.ZERO)
		g = _grab_driver.get_grab(by)
		if not g: return

	super.let_go(by, p_linear_velocity, p_angular_velocity)
	
	if not is_picked_up():
		_handle_final_fling(slide_snap)

func _handle_final_fling(strength: float) -> void:
	_reset_windup_audio()
	if _pending_fling_slide >= 0.0: strength = _pending_fling_slide
	_pending_fling_slide = -1.0
	
	if fling_y_velocity_max <= 0.0 or strength <= 0.0:
		is_in_flight = false
		return
	_fling_magnitude = fling_y_velocity_max * strength
	_fling_dir_world = (global_transform.basis.y * fling_along_local_y).normalized()
	_fling_ramp_t = 0.0
	_fling_w_prev = 0.0
	_is_fling_ramping = true
	if slide_position>0.5:
		is_in_flight = true

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	var prev_slide: float = slide_position
	_slide_process()
	_update_slide_position_01()
	_slide_velocity = (slide_position - prev_slide) / maxf(_delta, 1.0e-6)
	_update_windup_audio()
	_check_windup_haptics(prev_slide, slide_position)
	_fling_ramp_process(_delta)
	_process_in_flight_orientation()

func _slide_process() -> void:
	if not is_picked_up() or not is_instance_valid(_grab_driver) or not _grab_driver.secondary:
		_slide_anchors_ready = false
		return
	
	_slide_anchors_ready = true
	var p_by := _grab_driver.primary.by
	var s_by := _grab_driver.secondary.by
	
	# Map hand distance to local MainGrab position
	var hand_dist_world := p_by.global_position - s_by.global_position
	var shaft_w := global_transform.basis.y.normalized()
	var dist_along := hand_dist_world.dot(shaft_w)
	
	# Secondary is at some Y, Primary is dist_along away from it
	var target_y := _secondary_grab.position.y + (dist_along * inter_hand_y_flip)
	_main_grab.position.y = clampf(target_y, _compute_y_min(), _compute_y_max())
	
	# THE FIX: Directly update the driver's internal transform cache
	_grab_driver.primary.transform = _main_grab.transform

func apply_inter_hand_shaft_basis_post() -> void:
	if not is_instance_valid(_grab_driver) or not _grab_driver.secondary: return
	
	var p_by := _grab_driver.primary.by
	var s_by := _grab_driver.secondary.by
	var d_raw := s_by.global_position - p_by.global_position
	if d_raw.length_squared() < inter_hand_min_separation * inter_hand_min_separation: return
	
	var y_axis := d_raw.normalized() * inter_hand_y_flip
	
	# Build rotation basis
	var ref_u := global_transform.basis.y
	if absf(y_axis.dot(ref_u)) > _INTER_HAND_ROLL_PAR: ref_u = Vector3.UP
	var x_axis := y_axis.cross(ref_u).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var new_basis := Basis(x_axis, y_axis, z_axis)
	
	# ANCHOR: Use the secondary hand as the world origin point for the spear mesh
	var s_w := s_by.global_position
	var o := s_w - new_basis * _secondary_grab.position
	global_transform = Transform3D(new_basis, o)

func _refresh_driver_transforms() -> void:
	if not is_instance_valid(_grab_driver): return
	# Try the most common internal refresh methods in XRTools
	if _grab_driver.has_method("on_grab_point_moved"):
		_grab_driver.on_grab_point_moved(_main_grab)
	elif _grab_driver.has_method("update_grab_transforms"):
		_grab_driver.update_grab_transforms()

# --- Physics & Limits ---

func _update_slide_position_01() -> void:
	var span := _compute_y_max() - _compute_y_min()
	slide_position = 0.0 if is_zero_approx(span) else clampf((_main_grab.position.y - _compute_y_min()) / span, 0.0, 1.0)

func _compute_y_max() -> float: return _secondary_grab.position.y - max_y_epsilon
func _compute_y_min() -> float:
	var from_offset := _initial_main_y + min_y_offset_from_start
	return minf(from_offset, shaft_rear_stop.position.y) if shaft_rear_stop else from_offset

func _fling_ramp_process(delta: float) -> void:
	if not _is_fling_ramping: return
	_fling_ramp_t += delta
	var u := clampf(_fling_ramp_t / fling_ramp_duration, 0.0, 1.0)
	var w := 1.0 - pow(1.0 - u, 3.0)
	var dw := w - _fling_w_prev
	_fling_w_prev = w
	linear_velocity += _fling_dir_world * (_fling_magnitude * dw)
	if u >= 1.0: _is_fling_ramping = false

func _process_in_flight_orientation() -> void:
	if not is_in_flight:
		return
	var speed_sq := linear_velocity.length_squared()
	var min_speed_sq := in_flight_min_speed * in_flight_min_speed
	if speed_sq <= min_speed_sq and not _is_fling_ramping:
		is_in_flight = false
		return
	var reorient_min_sq := in_flight_reorient_min_speed * in_flight_reorient_min_speed
	if speed_sq <= reorient_min_sq:
		return
	var y_axis := linear_velocity.normalized()
	var ref_u := global_transform.basis.z
	if absf(y_axis.dot(ref_u)) > _INTER_HAND_ROLL_PAR:
		ref_u = Vector3.UP
	if absf(y_axis.dot(ref_u)) > _INTER_HAND_ROLL_PAR:
		ref_u = Vector3.RIGHT
	var x_axis := y_axis.cross(ref_u).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), global_position)

# --- Audio & Haptics ---

func _play_release_twang(slide_snap: float) -> void:
	if slide_snap < 0.5 or not _release_twang_player: return
	_release_twang_player.volume_db = lerpf(-20.0, 1.0, slide_snap)
	_release_twang_player.play()

func _update_windup_audio() -> void:
	if not _windup_player: return
	if not is_picked_up() or _slide_velocity <= 0.0:
		_reset_windup_audio(); return
	var t := clampf((_slide_velocity - windup_speed_for_min) / (windup_speed_for_max - windup_speed_for_min), 0.0, 1.0)
	if t <= 0.0: _reset_windup_audio(); return
	_windup_player.volume_db = lerpf(windup_min_volume_db, windup_max_volume_db, t)
	_windup_player.pitch_scale = lerpf(windup_min_pitch_scale, windup_max_pitch_scale, t)
	if not _windup_player.playing: _windup_player.play()

func _reset_windup_audio() -> void:
	if _windup_player and _windup_player.playing: _windup_player.stop()

func _trigger_grab_haptics(amp: float, dur: float) -> void:
	var seen: Array[XRController3D] = []
	for gr in [_grab_driver.primary, _grab_driver.secondary]:
		if is_instance_valid(gr) and is_instance_valid(gr.by):
			var c := XRHelpers.get_xr_controller(gr.by)
			if c and not seen.has(c):
				seen.append(c)
				c.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)

func _check_windup_haptics(prev_slide: float, cur_slide: float) -> void:
	if _windup_high_armed and prev_slide < windup_haptic_high_threshold and cur_slide >= windup_haptic_high_threshold:
		_trigger_grab_haptics(windup_haptic_high_amplitude, windup_haptic_high_duration)
		_windup_high_armed = false
	elif _windup_low_armed and prev_slide < windup_haptic_low_threshold and cur_slide >= windup_haptic_low_threshold:
		_trigger_grab_haptics(windup_haptic_low_amplitude, windup_haptic_low_duration)
		_windup_low_armed = false
	if cur_slide < windup_haptic_low_threshold - _WINDUP_REARM_HYSTERESIS: _windup_low_armed = true
	if cur_slide < windup_haptic_high_threshold - _WINDUP_REARM_HYSTERESIS: _windup_high_armed = true

func _play_release_haptic(slide_snap: float, releasing_by: Node3D) -> void:
	if slide_snap < fire_haptic_min_slide: return
	var t := (slide_snap - fire_haptic_min_slide) / (1.0 - fire_haptic_min_slide)
	var amp := lerpf(fire_haptic_min_amplitude, fire_haptic_max_amplitude, t)
	var dur := lerpf(fire_haptic_min_duration, fire_haptic_max_duration, t)
	_trigger_grab_haptics(amp, dur)
	var rc := XRHelpers.get_xr_controller(releasing_by)
	if rc: rc.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)

func _resolve_grab_point(p: XRToolsGrabPoint) -> XRToolsGrabPoint:
	var r := p
	while r is XRToolsGrabPointRedirect and is_instance_valid(r.target): r = r.target
	return r

func _is_resolved_point(a: XRToolsGrabPoint, b: XRToolsGrabPoint) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b): return false
	return _resolve_grab_point(a) == _resolve_grab_point(b)

func _on_grabbed(_pickable: XRToolsPickable, by: Node3D) -> void:
	_recompute_combo_counts_from_driver()
	_sync_lite_grab_hands()

func _on_released(_pickable: XRToolsPickable, by: Node3D) -> void:
	_recompute_combo_counts_from_driver()
	_sync_lite_grab_hands()

func _on_dropped(_pickable: XRToolsPickable) -> void:
	_recompute_combo_counts_from_driver()
	_sync_lite_grab_hands()

func _sync_lite_grab_hands() -> void:
	_set_mesh_visible(left_hand_on_left_point_mesh, _combo_active("left_left"))
	_set_mesh_visible(right_hand_on_left_point_mesh, _combo_active("right_left"))
	_set_mesh_visible(left_hand_on_right_point_mesh, _combo_active("left_right"))
	_set_mesh_visible(right_hand_on_right_point_mesh, _combo_active("right_right"))

func _set_mesh_visible(mesh_node: Node3D, is_visible: bool) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.visible = is_visible

func _combo_active(key: String) -> bool:
	return int(_combo_counts.get(key, 0)) > 0

func _combo_key_for(by: Node3D, resolved_point: XRToolsGrabPoint) -> String:
	var hand := _hand_from_grabber(by)
	if hand == "":
		return ""
	if is_instance_valid(left_lite_grab_point) and resolved_point == _resolve_grab_point(left_lite_grab_point):
		return "%s_left" % hand
	if is_instance_valid(right_lite_grab_point) and resolved_point == _resolve_grab_point(right_lite_grab_point):
		return "%s_right" % hand
	return ""

func _recompute_combo_counts_from_driver() -> void:
	_combo_counts.clear()
	if not is_instance_valid(_grab_driver):
		return
	_register_combo_for_grab(_grab_driver.primary)
	_register_combo_for_grab(_grab_driver.secondary)

func _register_combo_for_grab(grab: Variant) -> void:
	if not is_instance_valid(grab):
		return
	if not is_instance_valid(grab.by):
		return
	var resolved := _resolve_grab_point(grab.point)
	var combo_key := _combo_key_for(grab.by, resolved)
	if combo_key == "":
		return
	_combo_counts[combo_key] = int(_combo_counts.get(combo_key, 0)) + 1

func _hand_from_grabber(by: Node3D) -> String:
	var pickup := by as XRToolsFunctionPickup
	if not pickup:
		return ""
	var controller := pickup.get_controller()
	if not controller:
		return ""
	if controller.tracker == "left_hand":
		return "left"
	if controller.tracker == "right_hand":
		return "right"
	return ""
