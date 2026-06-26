@tool
extends XRToolsPickable
class_name ProSeaScooterPickable

enum DisplayMode { OFF, STOPPED, FORWARD_GEAR, REVERSE_UNTANGLE, REVERSE }
enum ReverseMode { NONE, UNTANGLE, REVERSE }

signal display_updated(mode: DisplayMode, gear: int)

@onready var main_grab: XRToolsGrabPoint = $MainGrabPoint
@onready var fan_visual: Node3D = $FanVisual
@onready var _motor_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _tip: Marker3D = $Tip

@onready var player_cam: Node3D = get_tree().get_first_node_in_group("Player") as Node3D

@onready var screen:DotMatrixDisplay=$No_Bake_Sea_Scooter/Complex_Body/Screen

var current_state: ProScooterState
var reverse_mode: ReverseMode = ReverseMode.NONE
## Normalized thrust magnitude (0 = off). Sign applied via [member thrust_sign].
var power: float = 0.0
var thrust_sign: float = 1.0
var is_left_just_grabbed: bool = false
var _primary_hold_is_left: bool = false

var forward_gear: int = 0
var motor_running: bool = false
var _cleared_slow_restart: bool = false
var _stopped_forward_gear: int = 0

var _yaw_momentum: float = 0.0
var _pitch_momentum: float = 0.0
var _safe_start_active: bool = false
var _boost_run_time: float = 0.0
var _was_trigger_held: bool = false

var _click_detector: TriggerClickDetector
var _player_body: XRToolsPlayerBody = null
var _motor_rumble_event: XRToolsRumbleEvent = null
var _motor_rumble_active: bool = false
var _motor_rumble_tracker: StringName = &""
var _lite_main_grab_hand_left_local_rest := Transform3D.IDENTITY
var _lite_main_grab_hand_right_local_rest := Transform3D.IDENTITY

@export_group("BlackTip Gears")
@export var gear_count: int = 8
@export var start_gear: int = 3
@export var jump_gear: int = 6
@export var power_by_gear: PackedFloat32Array = PackedFloat32Array([
	0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0
])

@export_group("BlackTip Reverse")
@export var reverse_untangle_power: float = 0.08
@export var reverse_power: float = 0.22

@export_group("BlackTip Safe Start")
@export var safe_start_power_cap: float = 0.15

@export_group("BlackTip Boost")
@export var boost_gear_threshold: int = 7
@export var boost_time_at_gear_8_sec: float = 420.0
@export var boost_time_at_gear_7_sec: float = 600.0
@export var boost_floor_gear: int = 6

@export_group("Click Detection")
@export var click_pattern_quiet_seconds: float = 0.48

@export_group("Lite Grab Hands")
@export var left_hand_main_grab_point_mesh: Node3D
@export var right_hand_main_grab_point_mesh: Node3D

@export_group("Submerged drop")
@export var submerged_drop_linear_speed_cap: float = 3.5

@export_group("Propulsion")
@export var max_fan_rpm: float = 800.0
@export var max_speed: float = 5.0

@export_group("Tow")
@export var tow_response: float = 6.0
@export var tow_rotation_yaw_speed: float = 90.0
@export var tow_rotation_pitch_speed: float = 90.0
@export var tow_rotation_min_to_tip_length: float = 0.05
@export var tow_rotation_dead_zone_deg: float = 6.0
@export var tow_rotation_full_response_deg: float = 45.0
@export var tow_rotation_response_exponent: float = 2.0

@export_group("Motor Audio")
@export var motor_power_for_min: float = 0.02
@export var motor_min_volume_db: float = -40.0
@export var motor_mid_volume_db: float = -5.0
@export var motor_max_volume_db: float = 4.0
@export var motor_min_pitch_scale: float = 0.75
@export var motor_mid_pitch_scale: float = 1.0
@export var motor_max_pitch_scale: float = 1.3

@export_group("Motor Haptics")
@export var motor_haptic_min_magnitude: float = 0.06
@export var motor_haptic_mid_magnitude: float = 0.14
@export var motor_haptic_max_magnitude: float = 0.32


func _ready() -> void:
	super()
	process_physics_priority = -10
	_click_detector = TriggerClickDetector.new()
	_click_detector.pattern_quiet_seconds = click_pattern_quiet_seconds
	_click_detector.pattern_completed.connect(_on_click_pattern_completed)
	_ensure_power_by_gear_size()
	grabbed.connect(_on_scooter_grabbed)
	released.connect(_on_scooter_released)
	_emit_display(DisplayMode.STOPPED,0)


func _ensure_power_by_gear_size() -> void:
	if power_by_gear.size() >= gear_count:
		return
	power_by_gear.resize(gear_count)
	for i in range(power_by_gear.size()):
		if power_by_gear[i] <= 0.0:
			power_by_gear[i] = float(i + 1) / float(gear_count)


func cleanup_before_unequip() -> void:
	_stop_motor()
	_reset_motor_audio()
	_reset_motor_haptics()
	exit_held_grab_pose()
	if current_state:
		current_state.exit()
		current_state = null
	if is_picked_up():
		drop()
	_player_body = null
	_click_detector.reset()
	_emit_display(DisplayMode.OFF, 0)


func _exit_tree() -> void:
	_reset_motor_haptics()
	if not Engine.is_editor_hint() and is_picked_up():
		drop()
	super()


func change_state(new_state: ProScooterState, params: Dictionary = {}) -> void:
	if current_state:
		current_state.exit(new_state)
	current_state = new_state
	current_state.enter(self, params)


func _on_click_pattern_completed(click_count: int) -> void:
	if not is_picked_up() or current_state == null:
		return
	current_state.handle_click_pattern(click_count)


func _on_scooter_grabbed(_pickable: XRToolsPickable, by: Node3D) -> void:
	if current_state != null:
		return
	var incoming_left := is_grab_left_handed(by)
	_primary_hold_is_left = incoming_left
	is_left_just_grabbed = incoming_left
	_resolve_player_body()
	_reset_control_state()
	enter_held_grab_pose(is_left_just_grabbed)
	change_state(ProScooterStoppedState.new())
	
	# Force the screen to sync with the initial stopped/0-gear state
	_emit_display(DisplayMode.STOPPED, forward_gear)



func _on_scooter_released(_pickable: XRToolsPickable, _by: Node3D) -> void:
	if not is_picked_up():
		_stop_motor()
		_reset_motor_audio()
		_reset_motor_haptics()
		exit_held_grab_pose()
		_player_body = null
		if current_state:
			current_state.exit()
			current_state = null
		_primary_hold_is_left = false
		_click_detector.reset()


func _reset_control_state() -> void:
	reverse_mode = ReverseMode.NONE
	forward_gear = 0
	motor_running = false
	thrust_sign = 1.0
	power = 0.0
	_cleared_slow_restart = false
	_stopped_forward_gear = 0
	_safe_start_active = false
	_boost_run_time = 0.0
	_was_trigger_held = false
	_click_detector.reset()


func _is_trigger_held() -> bool:
	var controller := get_picked_up_by_controller()
	return (
		controller != null
		and controller.get_is_active()
		and controller.is_button_pressed("trigger")
	)


func _restart_forward_gear() -> int:
	if _cleared_slow_restart:
		return start_gear
	if _stopped_forward_gear >= 1 and _stopped_forward_gear < start_gear:
		return _stopped_forward_gear
	return start_gear


func start_forward_motor() -> void:
	start_forward_motor_at_gear(_restart_forward_gear())


func start_forward_motor_at_gear(gear: int) -> void:
	set_forward_gear_and_run(gear)


func set_forward_gear_and_run(gear: int) -> void:
	reverse_mode = ReverseMode.NONE
	thrust_sign = 1.0
	forward_gear = clampi(gear, 1, gear_count)
	motor_running = _is_trigger_held()
	if motor_running:
		_safe_start_active = true
	change_state(ProScooterForwardState.new())
	if motor_running:
		_emit_display(DisplayMode.FORWARD_GEAR, forward_gear)
	else:
		_emit_display(DisplayMode.STOPPED, forward_gear)
	screen.show_number(gear)


func shift_forward_gear(delta: int) -> void:
	if forward_gear <= 0 or reverse_mode != ReverseMode.NONE:
		return
	var new_gear := clampi(forward_gear + delta, 1, gear_count)
	if new_gear == forward_gear:
		return
	forward_gear = new_gear
	if forward_gear > start_gear:
		_cleared_slow_restart = true
	
	# Check if the motor is running to determine if we show a solid number or blink
	if motor_running:
		_emit_display(DisplayMode.FORWARD_GEAR, forward_gear)
	else:
		_emit_display(DisplayMode.STOPPED, forward_gear)


func enter_reverse_untangle() -> void:
	reverse_mode = ReverseMode.UNTANGLE
	thrust_sign = -1.0
	forward_gear = 0
	motor_running = _is_trigger_held()
	if motor_running:
		_safe_start_active = true
	change_state(ProScooterReverseState.new())
	_emit_display(DisplayMode.REVERSE_UNTANGLE, 1)


func set_reverse_mode(mode: ReverseMode) -> void:
	if mode == ReverseMode.NONE:
		return
	reverse_mode = mode
	thrust_sign = -1.0
	motor_running = true
	if mode == ReverseMode.UNTANGLE:
		_emit_display(DisplayMode.REVERSE_UNTANGLE, 1)
	else:
		_emit_display(DisplayMode.REVERSE, 2)


func exit_reverse_mode() -> void:
	reverse_mode = ReverseMode.NONE
	thrust_sign = 1.0
	_stop_motor()
	change_state(ProScooterStoppedState.new())


## Release trigger: cut thrust but keep selected forward gear (BlackTip manual).
func _pause_thrust() -> void:
	if forward_gear > 0 and reverse_mode == ReverseMode.NONE:
		_stopped_forward_gear = forward_gear
	motor_running = false
	power = 0.0
	_boost_run_time = 0.0
	var display_gear := forward_gear
	if reverse_mode == ReverseMode.UNTANGLE:
		display_gear = 1
	elif reverse_mode == ReverseMode.REVERSE:
		display_gear = 2
	_emit_display(DisplayMode.STOPPED, display_gear)


## Full disengage (holster, exit reverse): clears gear selection.
func _stop_motor() -> void:
	if forward_gear > 0 and reverse_mode == ReverseMode.NONE:
		_stopped_forward_gear = forward_gear
	motor_running = false
	if reverse_mode == ReverseMode.NONE:
		forward_gear = 0
		thrust_sign = 1.0
	power = 0.0
	_boost_run_time = 0.0
	_safe_start_active = false
	_emit_display(DisplayMode.STOPPED, 0)


func _emit_display(mode: DisplayMode, gear: int) -> void:
	display_updated.emit(mode, gear)
	
	if not is_instance_valid(screen):
		return
		
	match mode:
		DisplayMode.FORWARD_GEAR:
			screen.show_number(gear)
		DisplayMode.STOPPED:
					if reverse_mode == ReverseMode.UNTANGLE:
						screen.show_reverse_untangle()
					elif reverse_mode == ReverseMode.REVERSE:
						screen.show_reverse_fast()
					elif gear > 0:
						# We are in a forward gear but the trigger is released
						screen.show_forward_ready()
					else:
						# We are in neutral (gear 0), play the tutorial blink
						screen.play_idle_animation()
		DisplayMode.REVERSE_UNTANGLE:
			screen.show_reverse_untangle()
		DisplayMode.REVERSE:
			screen.show_reverse_fast()
		DisplayMode.OFF:
			screen.clear()


func _power_for_forward_gear(gear: int) -> float:
	if gear < 1 or gear > power_by_gear.size():
		return 0.0
	return power_by_gear[gear - 1]


func _base_motor_power() -> float:
	if reverse_mode == ReverseMode.UNTANGLE:
		return reverse_untangle_power
	if reverse_mode == ReverseMode.REVERSE:
		return reverse_power
	if forward_gear <= 0:
		return 0.0
	return _power_for_forward_gear(forward_gear)


func _boost_time_limit_for_gear() -> float:
	if forward_gear >= 8:
		return boost_time_at_gear_8_sec
	if forward_gear >= boost_gear_threshold:
		return boost_time_at_gear_7_sec
	return INF


func _boost_multiplier() -> float:
	if reverse_mode != ReverseMode.NONE:
		return 1.0
	if forward_gear < boost_gear_threshold:
		return 1.0
	var limit := _boost_time_limit_for_gear()
	if limit <= 0.0 or _boost_run_time < limit:
		return 1.0
	var floor_power := _power_for_forward_gear(boost_floor_gear)
	var base := _base_motor_power()
	if base <= 0.0:
		return 1.0
	return clampf(floor_power / base, 0.35, 1.0)


func _effective_motor_power() -> float:
	if not _is_trigger_held():
		return 0.0
	if reverse_mode == ReverseMode.NONE and forward_gear <= 0:
		return 0.0
	var base := _base_motor_power()
	if _safe_start_active and not _is_scooter_submerged():
		base = minf(base, safe_start_power_cap)
	else:
		_safe_start_active = false
	base *= _boost_multiplier()
	return base


func _update_motor_and_power(delta: float) -> void:
	var held := _is_trigger_held()
	var controller := get_picked_up_by_controller()
	if forward_gear > 0 and reverse_mode == ReverseMode.NONE:
		if held:
			motor_running = true
			if current_state is ProScooterStoppedState:
				change_state(ProScooterForwardState.new())
			if not _was_trigger_held:
				_emit_display(DisplayMode.FORWARD_GEAR, forward_gear)
		elif motor_running:
			_pause_thrust()
	elif reverse_mode != ReverseMode.NONE:
		if held:
			motor_running = true
			if current_state is ProScooterStoppedState:
				change_state(ProScooterReverseState.new())
		elif motor_running:
			_pause_thrust()
			if current_state is not ProScooterStoppedState:
				change_state(ProScooterStoppedState.new())
	_was_trigger_held = held

	if motor_running and reverse_mode == ReverseMode.NONE and forward_gear >= boost_gear_threshold and held:
		_boost_run_time += delta

	power = _effective_motor_power()

	if controller:
		_click_detector.pattern_quiet_seconds = click_pattern_quiet_seconds
		_click_detector.poll(controller, delta)


func _player_state_machine_or_null() -> PlayerStateMachine:
	var scene = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return null
	var nodes = scene.find_children("*", "PlayerStateMachine", true, false)
	for n in nodes:
		if n is PlayerStateMachine:
			return n as PlayerStateMachine
	return null


func _is_player_submerged() -> bool:
	var psm: PlayerStateMachine = _player_state_machine_or_null()
	if psm == null or psm.current_state == null:
		return false
	return psm.current_state is SubmergedState


func _water_surface_y_at(x: float, z: float) -> float:
	var waves := get_tree().get_first_node_in_group("Waves") as Waves
	if waves and is_instance_valid(waves):
		return waves.getWaveHeight(x, z)
	return 0.0


func _is_scooter_submerged() -> bool:
	var pos := global_position
	return pos.y + 0.05 < _water_surface_y_at(pos.x, pos.z)


func _sanitize_drop_linear_velocity(incoming: Vector3) -> Vector3:
	if not _is_player_submerged():
		return incoming
	var max_spd: float = submerged_drop_linear_speed_cap
	if max_spd <= 0.0:
		return incoming
	@warning_ignore("shadowed_global_identifier")
	var len: float = incoming.length()
	if len <= max_spd:
		return incoming
	return incoming * (max_spd / len)


func snapshot_main_grab_lite_hand_local_rest() -> void:
	if is_instance_valid(left_hand_main_grab_point_mesh):
		_lite_main_grab_hand_left_local_rest = left_hand_main_grab_point_mesh.transform
	if is_instance_valid(right_hand_main_grab_point_mesh):
		_lite_main_grab_hand_right_local_rest = right_hand_main_grab_point_mesh.transform


func _approximate_chest_world() -> Vector3:
	var cam: Node3D = player_cam
	if cam == null or not is_instance_valid(cam):
		cam = get_tree().get_first_node_in_group("Player") as Node3D
	if cam == null:
		return Vector3.ZERO
	var sum: Vector3 = cam.global_position
	var count: int = 1
	if _player_body != null and is_instance_valid(_player_body):
		var left: XRController3D = _player_body.left_hand_node
		var right: XRController3D = _player_body.right_hand_node
		if left != null and is_instance_valid(left):
			sum += left.global_position
			count += 1
		if right != null and is_instance_valid(right):
			sum += right.global_position
			count += 1
	return sum / float(count)


func _rotate_origin_about_camera(axis_world: Vector3, angle: float) -> void:
	if _player_body == null or not is_instance_valid(_player_body):
		return
	var origin := _player_body.origin_node
	var camera := _player_body.camera_node
	if origin == null or camera == null:
		return
	if absf(angle) < 0.00001:
		return
	axis_world = axis_world.normalized()
	if axis_world.length_squared() < 0.0001:
		return
	var axis_local := (origin.global_transform.basis.inverse() * axis_world).normalized()
	if axis_local.length_squared() < 0.0001:
		return
	var t1 := Transform3D()
	t1.origin = -camera.transform.origin
	var t2 := Transform3D()
	t2.origin = camera.transform.origin
	var rot := Transform3D()
	rot = rot.rotated(axis_local, angle)
	origin.transform = (origin.transform * t2 * rot * t1).orthonormalized()


func _tow_rotation_response_scale(abs_angle_err_rad: float) -> float:
	var dead_rad: float = deg_to_rad(tow_rotation_dead_zone_deg)
	if abs_angle_err_rad <= dead_rad:
		return 0.0
	var full_rad: float = deg_to_rad(tow_rotation_full_response_deg)
	var span: float = maxf(full_rad - dead_rad, 0.001)
	var excess: float = abs_angle_err_rad - dead_rad
	var t: float = clampf(excess / span, 0.0, 1.0)
	return pow(t, maxf(tow_rotation_response_exponent, 0.01))


func _apply_axis_alignment(
		delta: float,
		from_dir: Vector3,
		to_dir: Vector3,
		rotation_axis: Vector3,
		speed_deg: float,
		align_scale: float
) -> void:
	rotation_axis = rotation_axis.normalized()
	if rotation_axis.length_squared() < 0.0001 or align_scale <= 0.0:
		return
	var from_in_plane := from_dir - rotation_axis * from_dir.dot(rotation_axis)
	var to_in_plane := to_dir - rotation_axis * to_dir.dot(rotation_axis)
	if from_in_plane.length_squared() < 0.0001 or to_in_plane.length_squared() < 0.0001:
		return
	from_in_plane = from_in_plane.normalized()
	to_in_plane = to_in_plane.normalized()
	var angle_err := from_in_plane.signed_angle_to(to_in_plane, rotation_axis)
	var response: float = _tow_rotation_response_scale(absf(angle_err))
	if response <= 0.0:
		return
	var max_step := deg_to_rad(speed_deg) * delta * align_scale
	var step := clampf(angle_err * response, -max_step, max_step)
	_rotate_origin_about_camera(rotation_axis, step)


func _apply_tow(delta: float, shaft_axis_world: Vector3) -> void:
	if _player_body == null or not is_instance_valid(_player_body):
		return
	var chest_pos: Vector3 = _approximate_chest_world()
	var to_tip: Vector3 = _tip.global_position - chest_pos
	var forward_dir := shaft_axis_world.normalized()
	var steering_dir := forward_dir
	if to_tip.length() >= tow_rotation_min_to_tip_length:
		steering_dir = to_tip.normalized()
	var current_vel := _player_body.velocity
	var forward_speed := current_vel.dot(forward_dir)
	var lateral_vel := current_vel - (forward_dir * forward_speed)
	var lateral_drag := 3.5 * delta
	var lateral_damped := lateral_vel.lerp(Vector3.ZERO, minf(lateral_drag, 1.0))
	var signed_power := power * thrust_sign
	var target_forward_speed := max_speed * signed_power
	var acceleration_blend := clampf(tow_response * delta, 0.0, 1.0)
	var new_forward_speed := lerpf(forward_speed, target_forward_speed, acceleration_blend)
	_player_body.velocity = lateral_damped + (forward_dir * new_forward_speed)
	_apply_hydrodynamic_rotation(delta, steering_dir, forward_dir)


func _apply_hydrodynamic_rotation(delta: float, from_dir: Vector3, to_dir: Vector3) -> void:
	var up := _player_body.up_player.normalized()
	var align_scale := absf(power)
	var target_yaw := _calculate_target_angular_velocity(
		from_dir, to_dir, up, tow_rotation_yaw_speed, align_scale
	)
	var pitch_axis := up.cross(to_dir.slide(up)).normalized()
	var target_pitch := 0.0
	if pitch_axis.length_squared() > 0.0001:
		target_pitch = _calculate_target_angular_velocity(
			from_dir, to_dir, pitch_axis, tow_rotation_pitch_speed, align_scale
		)
	var angular_drag := 4.0 * delta
	_yaw_momentum = lerpf(_yaw_momentum, target_yaw, angular_drag)
	_pitch_momentum = lerpf(_pitch_momentum, target_pitch, angular_drag)
	if absf(_yaw_momentum) > 0.0001:
		_rotate_origin_about_camera(up, _yaw_momentum * delta)
	if absf(_pitch_momentum) > 0.0001:
		_rotate_origin_about_camera(pitch_axis, _pitch_momentum * delta)


func _calculate_target_angular_velocity(
		from_dir: Vector3,
		to_dir: Vector3,
		rotation_axis: Vector3,
		max_speed_deg: float,
		align_scale: float
) -> float:
	if align_scale <= 0.0:
		return 0.0
	var from_in_plane := from_dir - rotation_axis * from_dir.dot(rotation_axis)
	var to_in_plane := to_dir - rotation_axis * to_dir.dot(rotation_axis)
	if from_in_plane.length_squared() < 0.0001 or to_in_plane.length_squared() < 0.0001:
		return 0.0
	var angle_err := from_in_plane.normalized().signed_angle_to(to_in_plane.normalized(), rotation_axis)
	var abs_err := absf(angle_err)
	var dead_rad := deg_to_rad(tow_rotation_dead_zone_deg)
	if abs_err <= dead_rad:
		return 0.0
	var full_rad := deg_to_rad(tow_rotation_full_response_deg)
	var span := maxf(full_rad - dead_rad, 0.001)
	var t := clampf((abs_err - dead_rad) / span, 0.0, 1.0)
	var smooth_t := t * t * (3.0 - 2.0 * t)
	var response := smooth_t * align_scale
	return signf(angle_err) * deg_to_rad(max_speed_deg) * response


func _motor_volume_db_for_power(p: float) -> float:
	if p <= 0.5:
		return lerpf(motor_min_volume_db, motor_mid_volume_db, p / 0.5)
	return lerpf(motor_mid_volume_db, motor_max_volume_db, (p - 0.5) / 0.5)


func _motor_pitch_scale_for_power(p: float) -> float:
	if p <= 0.5:
		return lerpf(motor_min_pitch_scale, motor_mid_pitch_scale, p / 0.5)
	return lerpf(motor_mid_pitch_scale, motor_max_pitch_scale, (p - 0.5) / 0.5)


func _reset_motor_audio() -> void:
	if _motor_player and _motor_player.playing:
		_motor_player.stop()


func _update_motor_audio_from_power(motor_power: float) -> void:
	if Engine.is_editor_hint() or not _motor_player or not is_picked_up():
		_reset_motor_audio()
		return
	if motor_power < motor_power_for_min:
		_reset_motor_audio()
		return
	_motor_player.volume_db = _motor_volume_db_for_power(motor_power)
	_motor_player.pitch_scale = _motor_pitch_scale_for_power(motor_power)
	if not _motor_player.playing:
		_motor_player.play()


func _ensure_motor_rumble_event() -> void:
	if _motor_rumble_event == null:
		_motor_rumble_event = XRToolsRumbleEvent.new()
		_motor_rumble_event.indefinite = true


func _motor_haptic_magnitude_for_power(p: float) -> float:
	if p <= 0.5:
		return lerpf(motor_haptic_min_magnitude, motor_haptic_mid_magnitude, p / 0.5)
	return lerpf(motor_haptic_mid_magnitude, motor_haptic_max_magnitude, (p - 0.5) / 0.5)


func _reset_motor_haptics() -> void:
	if not _motor_rumble_active:
		return
	if _motor_rumble_tracker != &"":
		XRToolsRumbleManager.clear(self, [_motor_rumble_tracker])
	_motor_rumble_active = false
	_motor_rumble_tracker = &""


func _update_motor_haptics_from_power(motor_power: float) -> void:
	if Engine.is_editor_hint() or not is_picked_up():
		_reset_motor_haptics()
		return
	if motor_power < motor_power_for_min:
		_reset_motor_haptics()
		return
	var controller := get_picked_up_by_controller()
	if controller == null or not is_instance_valid(controller):
		_reset_motor_haptics()
		return
	_ensure_motor_rumble_event()
	_motor_rumble_event.magnitude = _motor_haptic_magnitude_for_power(motor_power)
	var tracker: StringName = controller.tracker
	if not _motor_rumble_active or _motor_rumble_tracker != tracker:
		if _motor_rumble_active:
			_reset_motor_haptics()
		XRToolsRumbleManager.add(self, _motor_rumble_event, [tracker])
		_motor_rumble_active = true
		_motor_rumble_tracker = tracker


func _apply_fan(delta: float) -> void:
	if power <= 0.0:
		return
	if not is_instance_valid(fan_visual):
		return
	var shaft_axis_world: Vector3 = $BodyCollision.global_transform.basis.y.normalized()
	var rpm: float = max_fan_rpm * power
	var omega_rad_s: float = deg_to_rad(rpm * 360.0 / 60.0)
	fan_visual.rotate_object_local(Vector3.UP, omega_rad_s * delta)
	if not _is_scooter_submerged():
		return
	_apply_tow(delta, shaft_axis_world)


func _resolve_player_body() -> void:
	_player_body = null
	var xr_camera := get_tree().get_first_node_in_group("Player")
	if xr_camera == null:
		return
	var origin := xr_camera.get_parent()
	if origin == null:
		return
	_player_body = XRToolsPlayerBody.find_instance(origin)


func can_pick_up(by: Node3D) -> bool:
	if not super.can_pick_up(by):
		return false
	if is_picked_up():
		return false
	return true


func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	if is_picked_up() and current_state != null:
		call_deferred("_restore_pickup_ref_after_blocked_let_go", by)
		return
	var safe_lin: Vector3 = _sanitize_drop_linear_velocity(p_linear_velocity)
	super.let_go(by, safe_lin, p_angular_velocity)


func _restore_pickup_ref_after_blocked_let_go(pickup: Node3D) -> void:
	if not is_instance_valid(self) or not is_instance_valid(pickup):
		return
	if not is_picked_up():
		return
	if pickup is XRToolsFunctionPickup and (pickup as XRToolsFunctionPickup).picked_up_object != self:
		(pickup as XRToolsFunctionPickup).picked_up_object = self


func _physics_process(delta: float) -> void:
	if not is_picked_up() or current_state == null:
		_reset_motor_audio()
		_reset_motor_haptics()
		return
	current_state.tick(delta)
	_update_motor_and_power(delta)
	_apply_fan(delta)
	var audio_power := absf(power)
	_update_motor_audio_from_power(audio_power)
	_update_motor_haptics_from_power(audio_power)


func enter_held_grab_pose(is_left_hand_leading: bool) -> void:
	var mg: XRToolsGrabPoint = main_grab
	if is_instance_valid(mg):
		mg.enabled = false
	show_single_hold_hands(is_left_hand_leading)
	snapshot_main_grab_lite_hand_local_rest()


func exit_held_grab_pose() -> void:
	power = 0.0
	hide_single_hold_hands(_primary_hold_is_left)
	if not is_picked_up():
		var mg: XRToolsGrabPoint = main_grab
		if is_instance_valid(mg):
			mg.enabled = true


func show_single_hold_hands(is_left_hand_leading: bool) -> void:
	_set_mesh_visible(left_hand_main_grab_point_mesh, is_left_hand_leading)
	_set_mesh_visible(right_hand_main_grab_point_mesh, not is_left_hand_leading)


func hide_single_hold_hands(_is_left_hand_leading: bool) -> void:
	_set_mesh_visible(left_hand_main_grab_point_mesh, false)
	_set_mesh_visible(right_hand_main_grab_point_mesh, false)


func _set_mesh_visible(mesh_node: Node3D, is_visible: bool) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.visible = is_visible


func is_grab_left_handed(by: Node3D) -> bool:
	var controller := XRHelpers.get_xr_controller(by)
	if controller:
		return controller.tracker == &"left_hand"
	push_error("Pro sea scooter pickable couldn't find controller on grab")
	return "left" in by.name.to_lower()
