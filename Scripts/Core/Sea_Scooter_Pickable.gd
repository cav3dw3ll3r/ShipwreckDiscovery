@tool
extends XRToolsPickable
class_name SeaScooterPickable

@onready var main_grab: XRToolsGrabPoint = $MainGrabPoint
@onready var fan_visual: Node3D = $FanVisual
@onready var fan_guard: Area3D = $Area3D
@onready var _motor_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _tip: Marker3D = $Tip

@onready var player_cam: Node3D = get_tree().get_first_node_in_group("Player") as Node3D
var _yaw_momentum: float = 0.0
var _pitch_momentum: float = 0.0
var current_state: ScooterState
## Normalized thrust/fan level while held (0 = off, 1 = max).
var power: float = 0.0
var is_left_just_grabbed: bool = false

## Leading hand side from the first grip.
var _primary_hold_is_left: bool = false

@export_group("Lite Grab Hands")
@export var left_hand_main_grab_point_mesh: Node3D
@export var right_hand_main_grab_point_mesh: Node3D

@export_group("Submerged drop")
@export var submerged_drop_linear_speed_cap: float = 3.5

@export_group("Propulsion")
@export var max_fan_rpm: float = 100.0
@export var max_speed: float = 5.0
@export var ramp_up_seconds: float = 1.5
@export var ramp_down_seconds: float = 1.5

@export_group("Tow")
@export var tow_response: float = 6.0
@export var tow_leash_strength: float = 2.0
@export var tow_leash_distance: float = 0.35

@export_group("Tow Rotation")
@export var tow_rotation_yaw_speed: float = 90.0
@export var tow_rotation_pitch_speed: float = 90.0
@export var tow_rotation_min_to_tip_length: float = 0.05
## No tow rotation torque while rope-vs-shaft error is below this (degrees).
@export var tow_rotation_dead_zone_deg: float = 6.0
## Misalignment (degrees beyond dead zone) at which rotation reaches full strength.
@export var tow_rotation_full_response_deg: float = 45.0
## Exponent on normalized excess error; >1 = soft near dead zone, stronger when far off.
@export var tow_rotation_response_exponent: float = 2.0

@export_group("Tow Debug")
@export var debug_draw_tow_vectors: bool = false
## Scales velocity arrows (target_vel, v_look) for visibility in the debug view.
@export var debug_velocity_display_scale: float = 0.2

@export_group("Motor Audio")
## Below this normalized power, the motor loop stops (avoids idle creep).
@export var motor_power_for_min: float = 0.02
@export var motor_min_volume_db: float = -40.0
## Volume at 50% power; matches amateur_sea_scooter AudioStreamPlayer3D default.
@export var motor_mid_volume_db: float = -5.0
@export var motor_max_volume_db: float = 4.0
@export var motor_min_pitch_scale: float = 0.75
@export var motor_mid_pitch_scale: float = 1.0
@export var motor_max_pitch_scale: float = 1.3

@export_group("Motor Haptics")
## Continuous rumble on the holding controller via [XRToolsRumbleManager].
@export var motor_haptic_min_magnitude: float = 0.06
@export var motor_haptic_mid_magnitude: float = 0.14
@export var motor_haptic_max_magnitude: float = 0.32

var _player_body: XRToolsPlayerBody = null
var _motor_rumble_event: XRToolsRumbleEvent = null
var _motor_rumble_active: bool = false
var _motor_rumble_tracker: StringName = &""
var _lite_main_grab_hand_left_local_rest := Transform3D.IDENTITY
var _lite_main_grab_hand_right_local_rest := Transform3D.IDENTITY


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


func _ready() -> void:
	super()
	process_physics_priority = -10
	grabbed.connect(_on_scooter_grabbed)
	released.connect(_on_scooter_released)


func cleanup_before_unequip() -> void:
	power = 0.0
	_reset_motor_audio()
	_reset_motor_haptics()
	exit_held_grab_pose()
	if current_state:
		current_state.exit()
		current_state = null
	if is_picked_up():
		drop()
	_player_body = null


func _exit_tree() -> void:
	_reset_motor_haptics()
	if not Engine.is_editor_hint() and is_picked_up():
		drop()
	super()


func change_state(new_state: ScooterState, params: Dictionary = {}) -> void:
	if current_state:
		current_state.exit(new_state)
	current_state = new_state
	current_state.enter(self, params)


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


func _apply_tow_body_rotation(
		delta: float,
		to_tip: Vector3,
		shaft_axis_world: Vector3
) -> void:
	if power <= 0.0:
		return
	if to_tip.length() < tow_rotation_min_to_tip_length:
		return
	var from_dir := to_tip.normalized()
	var to_dir := shaft_axis_world.normalized()
	var up := _player_body.up_player.normalized()
	var align_scale := power
	_apply_axis_alignment(
			delta, from_dir, to_dir, up, tow_rotation_yaw_speed, align_scale
	)
	var pitch_axis := up.cross(to_dir.slide(up))
	_apply_axis_alignment(
			delta,
			from_dir,
			to_dir,
			pitch_axis,
			tow_rotation_pitch_speed,
			align_scale
	)


func _apply_tow(delta: float, shaft_axis_world: Vector3) -> void:
	if _player_body == null or not is_instance_valid(_player_body):
		return
		
	var chest_pos: Vector3 = _approximate_chest_world()
	var to_tip: Vector3 = _tip.global_position - chest_pos
	
	# The scooter's physical direction in the world
	var forward_dir := shaft_axis_world.normalized()
	
	# The player's intended steering direction
	var steering_dir := forward_dir
	if to_tip.length() >= tow_rotation_min_to_tip_length:
		steering_dir = to_tip.normalized()
	
	# 1. HYDRODYNAMIC VELOCITY (Linear Momentum)
	var current_vel := _player_body.velocity
	var forward_speed := current_vel.dot(forward_dir)
	var lateral_vel := current_vel - (forward_dir * forward_speed)
	
	var lateral_drag := 3.5 * delta
	var lateral_damped := lateral_vel.lerp(Vector3.ZERO, minf(lateral_drag, 1.0))
	
	var target_forward_speed := max_speed * power
	var acceleration_blend := clampf(tow_response * delta, 0.0, 1.0)
	var new_forward_speed := lerpf(forward_speed, target_forward_speed, acceleration_blend)
	
	_player_body.velocity = lateral_damped + (forward_dir * new_forward_speed)
	
	# 2. FLUID VR ROTATION (Angular Momentum)
	# We call this constantly so momentum can decay naturally even if power is 0
	_apply_hydrodynamic_rotation(delta, steering_dir, forward_dir)


func _apply_hydrodynamic_rotation(delta: float, from_dir: Vector3, to_dir: Vector3) -> void:
	var up := _player_body.up_player.normalized()
	var align_scale := power
	
	# Calculate the TARGET turn speeds based on how hard the player is twisting
	var target_yaw := _calculate_target_angular_velocity(
		from_dir, to_dir, up, tow_rotation_yaw_speed, align_scale
	)
	
	var pitch_axis := up.cross(to_dir.slide(up)).normalized()
	var target_pitch := 0.0
	if pitch_axis.length_squared() > 0.0001:
		target_pitch = _calculate_target_angular_velocity(
			from_dir, to_dir, pitch_axis, tow_rotation_pitch_speed, align_scale
		)

	# THE MAGIC: Accumulate Angular Momentum (Inertia)
	# This is what makes the turn feel heavy and fluid as it builds up speed.
	var angular_drag := 4.0 * delta # Tweak this to change how fast the turn ramps up
	_yaw_momentum = lerpf(_yaw_momentum, target_yaw, angular_drag)
	_pitch_momentum = lerpf(_pitch_momentum, target_pitch, angular_drag)

	# Apply the accumulated momentum
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
	
	# Hermite Curve Smoothstep for organic acceleration
	var smooth_t := t * t * (3.0 - 2.0 * t)
	var response := smooth_t * align_scale
	
	# Returns the target speed in radians per second (preserving left/right sign)
	return signf(angle_err) * deg_to_rad(max_speed_deg) * response


func _apply_smoothed_axis_alignment(
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
	var abs_err := absf(angle_err)
	var dead_rad := deg_to_rad(tow_rotation_dead_zone_deg)
	
	if abs_err <= dead_rad:
		return
		
	var full_rad := deg_to_rad(tow_rotation_full_response_deg)
	var span := maxf(full_rad - dead_rad, 0.001)
	var excess := abs_err - dead_rad
	var t := clampf(excess / span, 0.0, 1.0)
	
	# MASTER MAGIC: The Hermite Curve Smoothstep
	# Completely replaces the legacy `pow(t, exponent)` logic for organic easing
	var smooth_t := t * t * (3.0 - 2.0 * t)
	var response := smooth_t * align_scale
	
	var max_step := deg_to_rad(speed_deg) * delta * response
	var step := clampf(angle_err, -max_step, max_step)
	
	_rotate_origin_about_camera(rotation_axis, step)

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


@warning_ignore("unused_parameter")
func _on_fan_collision(body:Node):
	pass

func _on_scooter_grabbed(_pickable: XRToolsPickable, by: Node3D) -> void:
	if current_state != null:
		return

	var incoming_left := is_grab_left_handed(by)
	_primary_hold_is_left = incoming_left
	is_left_just_grabbed = incoming_left
	_resolve_player_body()
	enter_held_grab_pose(is_left_just_grabbed)
	change_state(ScooterIdleState.new())


func _on_scooter_released(_pickable: XRToolsPickable, _by: Node3D) -> void:
	if not is_picked_up():
		power = 0.0
		_reset_motor_audio()
		_reset_motor_haptics()
		exit_held_grab_pose()
		_player_body = null
		if current_state:
			current_state.exit()
			current_state = null
		_primary_hold_is_left = false


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
	_apply_fan(delta)
	_update_motor_audio_from_power(power)
	_update_motor_haptics_from_power(power)


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


@warning_ignore("shadowed_variable_base_class")
func _set_mesh_visible(mesh_node: Node3D, is_visible: bool) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.visible = is_visible


func is_grab_left_handed(by: Node3D) -> bool:
	var controller := XRHelpers.get_xr_controller(by)
	if controller:
		return controller.tracker == &"left_hand"
	push_error("Sea scooter pickable couldn't find controller on grab")
	return "left" in by.name.to_lower()
