@tool
extends XRToolsPickable
class_name AmateurSpearPickable

@onready var main_grab = $MainGrabPoint
@onready var _windup_player: AudioStreamPlayer3D = $WindUpPlayer

var current_slide_pos: float = 0.0
var current_state: AmateurSpearHoldState
var is_left_just_grabbed: bool = false

var _windup_prev_slide_pos: float = 0.0
var _windup_prev_slide_valid: bool = false

var _primary_hold_is_left: bool = false

@export_group("Holster hand")
## Matches parent [Equipment_Holder] [member Equipment_Holder.off_hand]: false = spawn on right pickup.
@export var holster_spawn_on_left_hand: bool = false

@export_group("Lite Grab Hands")
@export var left_hand_main_grab_point_mesh: Node3D
@export var right_hand_main_grab_point_mesh: Node3D

@export_group("Trigger cocking")
## Slide speed (m/s) while dominant-hand trigger is held.
@export var trigger_cock_slide_speed_mps: float = 1.2
const _COCKED_SLIDE_MIN_FOR_COCKED_01: float = -0.8

@export_group("Submerged spear drop")
@export var submerged_drop_linear_speed_cap: float = 3.5

@export_group("Windup Audio (rubber band)")
@export var windup_speed_for_min: float = 0.05
@export var windup_speed_for_max: float = 1.5
@export var windup_min_volume_db: float = -24.0
@export var windup_max_volume_db: float = 2.0
@export var windup_min_pitch_scale: float = 0.85
@export var windup_max_pitch_scale: float = 1.25
@export var single_hold_reverse_quiet_volume_db_offset: float = -12.0
@export var single_hold_reverse_quiet_pitch_scale: float = 0.95

@export_group("Fire Haptics (trigger release)")
@export_range(0.0, 1.0) var fire_haptic_min_cocked_01: float = 0.95
@export var fire_haptic_min_amplitude: float = 0.2
@export var fire_haptic_max_amplitude: float = 0.9
@export var fire_haptic_min_duration: float = 0.05
@export var fire_haptic_max_duration: float = 0.18

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


func _sanitize_drop_linear_velocity(incoming: Vector3) -> Vector3:
	if not _is_player_submerged():
		return incoming
	var max_spd: float = submerged_drop_linear_speed_cap
	if max_spd <= 0.0:
		return incoming
	var l: float = incoming.length()
	if l <= max_spd:
		return incoming
	return incoming * (max_spd / l)


func _dominant_hand_is_left() -> bool:
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings and game_settings.switch_hands:
		return not holster_spawn_on_left_hand
	return holster_spawn_on_left_hand


func snapshot_main_grab_lite_hand_local_rest() -> void:
	if is_instance_valid(left_hand_main_grab_point_mesh):
		_lite_main_grab_hand_left_local_rest = left_hand_main_grab_point_mesh.transform
	if is_instance_valid(right_hand_main_grab_point_mesh):
		_lite_main_grab_hand_right_local_rest = right_hand_main_grab_point_mesh.transform


func refresh_main_grab_lite_hands_slide_visual(slip_dir_world: Vector3, slide_accum_m: float) -> void:
	var parent_nd := main_grab as Node3D
	if not is_instance_valid(parent_nd):
		return
	var offset_world: Vector3 = Vector3.ZERO
	if absf(slide_accum_m) > 1e-6:
		offset_world = -slip_dir_world.normalized() * slide_accum_m
	var offset_local := parent_nd.global_basis.inverse() * offset_world

	if is_instance_valid(left_hand_main_grab_point_mesh):
		var r := _lite_main_grab_hand_left_local_rest
		left_hand_main_grab_point_mesh.transform = Transform3D(r.basis, r.origin + offset_local)
	if is_instance_valid(right_hand_main_grab_point_mesh):
		var rr := _lite_main_grab_hand_right_local_rest
		right_hand_main_grab_point_mesh.transform = Transform3D(rr.basis, rr.origin + offset_local)


func is_dominant_trigger_pressed() -> bool:
	var controller := get_picked_up_by_controller()
	return (
		controller != null
		and controller.get_is_active()
		and controller.is_button_pressed("trigger")
	)


func _ready() -> void:
	super()
	grabbed.connect(_on_spear_grabbed)
	released.connect(_on_spear_released)


func cleanup_before_unequip() -> void:
	if current_state:
		current_state.exit()
		current_state = null
	if is_picked_up():
		drop()


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and is_picked_up():
		drop()
	super()


func change_state(new_state: AmateurSpearHoldState) -> void:
	if current_state:
		current_state.exit(new_state)
	current_state = new_state
	current_state.enter(self)


func _on_spear_grabbed(_pickable: XRToolsPickable, by: Node3D) -> void:
	var incoming_left := is_grab_left_handed(by)
	if current_state == null:
		_primary_hold_is_left = incoming_left
		is_left_just_grabbed = incoming_left
		change_state(AmateurSpearHoldState.new())


func _on_spear_released(_pickable: XRToolsPickable, _by: Node3D) -> void:
	if not is_picked_up():
		if current_state:
			current_state.exit()
			current_state = null
		_primary_hold_is_left = false


func can_pick_up(by: Node3D) -> bool:
	if not super.can_pick_up(by):
		return false
	if is_grab_left_handed(by) != _dominant_hand_is_left():
		return false
	if is_picked_up():
		return false
	return true


func pick_up(by: Node3D) -> void:
	if is_picked_up():
		return
	super.pick_up(by)
	_reset_windup_audio()
	mark_windup_slide_baseline()


func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	if current_state != null and is_grab_left_handed(by) == _primary_hold_is_left:
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


func mark_windup_slide_baseline() -> void:
	_windup_prev_slide_pos = current_slide_pos
	_windup_prev_slide_valid = true


func _reset_windup_audio() -> void:
	if _windup_player and _windup_player.playing:
		_windup_player.stop()


func _compute_cocked_01() -> float:
	var span := absf(_COCKED_SLIDE_MIN_FOR_COCKED_01)
	if span <= 1e-6:
		return 0.0
	return clampf((-current_slide_pos) / span, 0.0, 1.0)


func play_fire_haptic_if_fully_cocked() -> void:
	var cocked_01 := _compute_cocked_01()
	if cocked_01 < fire_haptic_min_cocked_01:
		return

	var denom := 1.0 - fire_haptic_min_cocked_01
	var t := 0.0 if denom <= 1.0e-6 else (cocked_01 - fire_haptic_min_cocked_01) / denom
	t = clampf(t, 0.0, 1.0)

	var amp := lerpf(fire_haptic_min_amplitude, fire_haptic_max_amplitude, t)
	var dur := lerpf(fire_haptic_min_duration, fire_haptic_max_duration, t)

	var pickup := get_picked_up_by()
	if pickup == null:
		return
	var rc := XRHelpers.get_xr_controller(pickup)
	if rc:
		rc.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)


func _update_windup_audio_from_slide_velocity(slide_velocity_m_s: float) -> void:
	if not _windup_player:
		return
	if not is_picked_up() or slide_velocity_m_s >= 0.0:
		_reset_windup_audio()
		return

	var stretch_speed_m_s := -slide_velocity_m_s
	var denom := windup_speed_for_max - windup_speed_for_min
	if denom <= 0.0:
		return

	var t := clampf((stretch_speed_m_s - windup_speed_for_min) / denom, 0.0, 1.0)
	if t <= 0.0:
		_reset_windup_audio()
		return

	_windup_player.volume_db = lerpf(windup_min_volume_db, windup_max_volume_db, t)
	_windup_player.pitch_scale = lerpf(windup_min_pitch_scale, windup_max_pitch_scale, t)
	if not _windup_player.playing:
		_windup_player.play()


func _update_quiet_windup_audio_from_reverse_slide_velocity(slide_velocity_m_s: float) -> void:
	if not _windup_player:
		return
	if not is_picked_up() or slide_velocity_m_s <= 0.0:
		_reset_windup_audio()
		return

	var denom := windup_speed_for_max - windup_speed_for_min
	if denom <= 0.0:
		return

	var stretch_speed_m_s := slide_velocity_m_s
	var t := clampf((stretch_speed_m_s - windup_speed_for_min) / denom, 0.0, 1.0)
	if t <= 0.0:
		_reset_windup_audio()
		return

	var vol_db := lerpf(windup_min_volume_db, windup_max_volume_db, t) + single_hold_reverse_quiet_volume_db_offset
	var pitch := lerpf(windup_min_pitch_scale, windup_max_pitch_scale, t) * single_hold_reverse_quiet_pitch_scale

	_windup_player.volume_db = vol_db
	_windup_player.pitch_scale = pitch
	if not _windup_player.playing:
		_windup_player.play()


func _physics_process(delta: float) -> void:
	if not is_picked_up():
		_windup_prev_slide_valid = false
		_reset_windup_audio()
		return

	if not current_state:
		_windup_prev_slide_valid = false
		_reset_windup_audio()
		return

	current_state.tick(delta)

	if not _windup_prev_slide_valid:
		mark_windup_slide_baseline()
		return

	var slide_vel_m_s := (current_slide_pos - _windup_prev_slide_pos) / maxf(delta, 1.0e-6)
	if slide_vel_m_s < 0.0:
		_update_windup_audio_from_slide_velocity(slide_vel_m_s)
	elif slide_vel_m_s > 0.0:
		_update_quiet_windup_audio_from_reverse_slide_velocity(slide_vel_m_s)
	else:
		_reset_windup_audio()

	_windup_prev_slide_pos = current_slide_pos


func set_main_hand_slide_position(slide_pos: float) -> void:
	var snap := _grab_driver.global_transform
	var shaft_world := snap.basis.y.normalized()
	var slip_dir := shaft_world
	var _shaft_slide_m = slide_pos - current_slide_pos

	_grab_driver.global_transform = Transform3D(
		snap.basis,
		snap.origin + slip_dir * current_slide_pos + slip_dir * _shaft_slide_m
	)
	refresh_main_grab_lite_hands_slide_visual(slip_dir, current_slide_pos + _shaft_slide_m)
	current_slide_pos = slide_pos


func show_single_hold_hands(is_left_hand_leading: bool) -> void:
	_set_mesh_visible(left_hand_main_grab_point_mesh, is_left_hand_leading)
	_set_mesh_visible(right_hand_main_grab_point_mesh, not is_left_hand_leading)


func _set_mesh_visible(mesh_node: Node3D, is_vizibl: bool) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.visible = is_vizibl


func is_grab_left_handed(by: Node3D) -> bool:
	var controller := XRHelpers.get_xr_controller(by)
	if controller:
		return controller.tracker == &"left_hand"
	push_error("Amateur spear pickable couldn't find controller on grab")
	return "left" in by.name.to_lower()
