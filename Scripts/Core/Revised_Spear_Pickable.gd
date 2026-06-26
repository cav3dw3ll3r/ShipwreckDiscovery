@tool
extends XRToolsPickable
class_name RevisedSpearPickable

@onready var main_grab = $MainGrabPoint
@onready var secondary_grab = $SecondaryGrabPoint
@onready var shaft_slide_rest = main_grab.position.y
@onready var _windup_player: AudioStreamPlayer3D = $WindUpPlayer

var current_slide_pos:float = 0.
var current_state:SpearState
var is_left_just_grabbed:bool = false

var _windup_prev_slide_pos: float = 0.0
var _windup_prev_slide_valid: bool = false

var _windup_prev_cocked_01: float = 0.0
var _windup_prev_cocked_valid: bool = false

var _windup_low_armed_double: bool = true
var _windup_high_armed_double: bool = true

## Leading hand side from the first grip (never both hands). Used for mesh/state and duplicate-hand rejects.
var _primary_hold_is_left: bool = false


@export_group("Lite Grab Hands")
@export var left_hand_main_grab_point_mesh: Node3D
@export var right_hand_main_grab_point_mesh: Node3D
@export var left_hand_secondary_grab_point_mesh: Node3D
@export var right_hand_secondary_grab_point_mesh: Node3D

## Hysteresis around [method XRTools.get_grip_threshold], matching [XRToolsFunctionPickup] grip edge handling.
const GRIP_HYSTERESIS := 0.1

@export_group("Single Hold Shaft Slack")

@export_group("Loaded state")
@export var zookeeper_scene: PackedScene = preload("res://Prefabs/Equipment/zookeeper.tscn")
@export var loaded_state_exploding_dummy_scene: PackedScene

@export_group("Zookeeper capture / trophy insertion")
## Internal capture progress along the tube (0–1); lerped to these shader insertion_progress endpoints.
@export var capture_insertion_progress_remap_min: float = 0.0
@export var capture_insertion_progress_remap_max: float = 1.0
## Trophy axial fraction in the capture tube (0–1): internal insertion stays 0 below this, ramps 0→1 up to axial_gate_full, then stays at 1.
@export_range(0.0, 1.0) var capture_insertion_axial_gate_begin: float = 0.2
## Internal insertion reaches 1 once axial fraction reaches this (swap with begin in inspector if reversing the ramp).
@export_range(0.0, 1.0) var capture_insertion_axial_gate_full: float = 0.3

@export_group("Submerged spear drop")
## Caps [XRToolsFunctionPickup] throw velocity while [PlayerStateMachine] is in [SubmergedState]. Frozen grabs that teleport the spear (double-hold, rubber-band) can spike XRTools velocity averages into huge launches.
@export var submerged_drop_linear_speed_cap: float = 3.5

@export_group("Windup Audio (rubber band)")
## Slide velocity threshold (m/s) to start playing the stretch clip.
@export var windup_speed_for_min: float = 0.05
## Slide velocity at which the clip reaches max volume/pitch.
@export var windup_speed_for_max: float = 1.5
@export var windup_min_volume_db: float = -24.0
@export var windup_max_volume_db: float = 2.0
@export var windup_min_pitch_scale: float = 0.85
@export var windup_max_pitch_scale: float = 1.25
## When in single-hold and the slide moves "opposite" (slack returning),
## apply extra quietness to avoid the rubber band sounding too aggressive.
@export var single_hold_reverse_quiet_volume_db_offset: float = -12.0
@export var single_hold_reverse_quiet_pitch_scale: float = 0.95

@export_group("Windup Haptics (rubber band, double-hold)")
@export var windup_haptic_low_threshold: float = 0.5
@export var windup_haptic_high_threshold: float = 0.95
@export var windup_haptic_low_amplitude: float = 0.25
@export var windup_haptic_low_duration: float = 0.05
@export var windup_haptic_high_amplitude: float = 0.8
@export var windup_haptic_high_duration: float = 0.12

const _WINDUP_REARM_HYSTERESIS: float = 0.05
## Double-hold `current_slide_pos` is clamped to [-0.8, 0.1], where pulling back is more negative.
const _DOUBLE_HOLD_SLIDE_MIN_FOR_COCKED_01: float = -0.8

@export_group("Fire Haptics (single-hold release)")
## Pulse only when cocked at/above this ratio (0..1).
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


func snapshot_main_grab_lite_hand_local_rest() -> void:
	if is_instance_valid(left_hand_main_grab_point_mesh):
		_lite_main_grab_hand_left_local_rest = left_hand_main_grab_point_mesh.transform
	if is_instance_valid(right_hand_main_grab_point_mesh):
		_lite_main_grab_hand_right_local_rest = right_hand_main_grab_point_mesh.transform

## Counteracts shaft slip on the lite grip meshes so they stay visually at the hand anchor while the spear body slides.
func refresh_main_grab_lite_hands_slide_visual(slip_dir_world: Vector3, slide_accum_m: float) -> void:
	var parent_nd := main_grab as Node3D
	if not is_instance_valid(parent_nd):
		return
	var offset_world: Vector3 = Vector3.ZERO
	if abs(slide_accum_m) > 1e-6:
		offset_world = - slip_dir_world.normalized() * slide_accum_m
	var offset_local := parent_nd.global_basis.inverse() * offset_world

	if is_instance_valid(left_hand_main_grab_point_mesh):
		var r := _lite_main_grab_hand_left_local_rest
		left_hand_main_grab_point_mesh.transform = Transform3D(r.basis, r.origin + offset_local)
	if is_instance_valid(right_hand_main_grab_point_mesh):
		var rr := _lite_main_grab_hand_right_local_rest
		right_hand_main_grab_point_mesh.transform = Transform3D(rr.basis, rr.origin + offset_local)


func get_primary_function_pickup() -> XRToolsFunctionPickup:
	if _grab_driver == null or _grab_driver.primary == null:
		return null
	return _grab_driver.primary.pickup as XRToolsFunctionPickup


func get_primary_hand_grip_strength() -> float:
	var fn := get_primary_function_pickup()
	if fn == null:
		return 0.0
	var controller := XRHelpers.get_xr_controller(fn)
	if controller == null or not controller.get_is_active():
		return 0.0
	return controller.get_float(fn.pickup_axis_action)


## True when grip is firmly past threshold (upper hysteresis band). Use to commit out of rubber-band follow.
func is_primary_hand_grip_engaged() -> bool:
	return get_primary_hand_grip_strength() > XRTools.get_grip_threshold() + GRIP_HYSTERESIS


## Non-primary physical hand [XRToolsFunctionPickup] (zookeeper net, etc.) opposite the spear's current primary hold.
func get_off_hand_pickup() -> XRToolsFunctionPickup:
	var off_hand_is_left := not _primary_hold_is_left
	var xr_camera := get_tree().get_first_node_in_group("Player")
	if xr_camera == null:
		return null
	var origin := xr_camera.get_parent()
	if origin == null:
		return null
	return XRToolsFunctionPickup.find_left(origin) if off_hand_is_left else XRToolsFunctionPickup.find_right(origin)


func get_spear_trophy() -> Node3D:
	var tip_nd := get_node_or_null("Tip")
	if tip_nd == null:
		return null
	var cand: Variant = tip_nd.get("current_trophy")
	if cand == null or not (cand is Node3D) or not is_instance_valid(cand):
		return null
	var n := cand as Node3D
	if not is_instance_valid(n) or n.get_parent() != tip_nd:
		return null
	return n


func clear_spear_trophy_reference_after_tip_transfer() -> void:
	var tip_nd := get_node_or_null("Tip")
	if tip_nd == null or not tip_nd.has_method("clear_spear_trophy_reference_from_transfer"):
		return
	tip_nd.clear_spear_trophy_reference_from_transfer()


## Move [param spear_trophy] descendants from [param zk] to [param dummy] with preserved world pose;
## used when the zookeeper RB is about to be freed (loaded-state teardown or capture outro).
static func reparent_spear_trophies_zk_to_dummy(zk: Node3D, dummy: Node, s: RevisedSpearPickable) -> void:
	if not is_instance_valid(zk) or not is_instance_valid(dummy):
		return
	for n in zk.find_children("*", "Node3D", true, false):
		if not n.is_in_group("spear_trophy"):
			continue
		var trophy := n as Node3D
		var xf := trophy.global_transform
		trophy.reparent(dummy, true)
		trophy.global_transform = xf
		trophy.remove_from_group(DeadLionfish.GROUP_SPEAR_TROPHY_CAGED)
		var mn := 0.0
		var mx := 1.0
		if s != null:
			mn = s.capture_insertion_progress_remap_min
			mx = s.capture_insertion_progress_remap_max
		if trophy.has_method("set_insertion_progress"):
			trophy.call("set_insertion_progress", lerpf(mn, mx, 1.0))
		if trophy.has_method("reset_motion_shader_baseline"):
			trophy.call("reset_motion_shader_baseline")


func _ready() -> void:
	#Gotta call super yeah 
	super()
	$Tip.connect("on_kill",_on_fish_kill)
	grabbed.connect(_on_spear_grabbed)
	released.connect(_on_spear_released)

func _teardown_offhand_zookeeper_if_bound() -> void:
	var pickup := get_off_hand_pickup()
	if pickup == null:
		return
	var held := pickup.picked_up_object
	if not (held is ZookeeperPickable):
		return
	var zk := held as ZookeeperPickable
	if zk.get_bound_spear() != self:
		return
	zk.prepare_for_forced_off_hand_teardown()
	var z_inst := zk as Node3D
	var xf := z_inst.global_transform
	var scene_root := get_tree().current_scene
	if is_instance_valid(self) and loaded_state_exploding_dummy_scene != null and scene_root:
		var dummy := loaded_state_exploding_dummy_scene.instantiate() as Node3D
		if dummy != null:
			scene_root.add_child(dummy)
			dummy.global_transform = xf
			RevisedSpearPickable.reparent_spear_trophies_zk_to_dummy(z_inst, dummy, self)
	elif scene_root:
		RevisedSpearPickable.reparent_spear_trophies_zk_to_dummy(z_inst, scene_root, self)
	if pickup.picked_up_object == zk:
		pickup.drop_object()
	if is_instance_valid(zk):
		zk.queue_free()


func cleanup_before_unequip() -> void:
	if current_state:
		current_state.exit()
		current_state = null
	_teardown_offhand_zookeeper_if_bound()
	if is_picked_up():
		drop()


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and is_picked_up():
		drop()
	super()


func change_state(new_state: SpearState, params: Dictionary = {}):
	if current_state:
		current_state.exit(new_state)

	current_state=new_state
	current_state.enter(self, params)

func _on_fish_kill():
	change_state(SpearLoadedState.new())

func _on_spear_grabbed(_pickable:XRToolsPickable, by:Node3D)->void:
	var incoming_left := is_grab_left_handed(by)
	# XR can emit grabbed again for grip spam/same-controller nodes; skip second-hand transition with same leading side.
	if current_state is SpearSingleHoldState and incoming_left == _primary_hold_is_left:
		return

	# For now, null means "holstered/not in active state yet".
	if current_state == null:
		_primary_hold_is_left = incoming_left
		is_left_just_grabbed = incoming_left
		change_state(SpearSingleHoldState.new())
	elif current_state is SpearSingleHoldState:
		is_left_just_grabbed = incoming_left
		change_state(SpearDoubleHoldState.new())
	else:
		pass

func _on_spear_released(_pickable:XRToolsPickable, by:Node3D)->void:
	var released_left := is_grab_left_handed(by)
	if not is_picked_up():
		if current_state:
			current_state.exit()
			current_state = null
		_primary_hold_is_left = false
		return

	if current_state is SpearDoubleHoldState and _grab_driver and _grab_driver.primary:
		# Double->single should only happen when the secondary hand lets go.
		if released_left != _primary_hold_is_left:
			is_left_just_grabbed = _primary_hold_is_left
			change_state(SpearSingleHoldState.new())

func can_pick_up(by: Node3D) -> bool:
	if not super.can_pick_up(by):
		return false
	# let_go noop + press_to_hold drop clears FunctionPickup reference but keeps our grab_driver.
	# Grip spam would call pick_up again and corrupt primary/secondary (same hand as "second").
	if is_picked_up() and _grab_driver and _grab_driver.get_grab(by):
		if not _is_stale_non_primary_grab_lock(by):
			return false
	if is_picked_up() and _grab_driver and _shares_tracker_with_existing_grabs(by):
		return false
	return true


func pick_up(by: Node3D) -> void:
	if is_picked_up() and _grab_driver and _grab_driver.get_grab(by):
		if not _is_stale_non_primary_grab_lock(by):
			return
	if is_picked_up() and _grab_driver and _shares_tracker_with_existing_grabs(by):
		return
	super.pick_up(by)
	_reset_windup_audio()
	mark_windup_slide_baseline()
	_windup_low_armed_double = true
	_windup_high_armed_double = true


func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	# In double-hold, only allow the secondary hand to release.
	# SpearCapturedState extends SpearState only (not SpearSingleHoldState), but must use the same
	# primary-hand release blocking as single-hold so grip drop / toggle-drop cannot exit capture.
	if current_state is SpearSingleHoldState or current_state is SpearCapturedState:
		var by_is_primary_side := is_grab_left_handed(by) == _primary_hold_is_left
		# Only repair pickup ref for the actual main-hand owner side.
		# Off-hand calls (even with stale by_grab residue) must never re-anchor ownership.
		if by_is_primary_side:
			# "Fire" haptic: a full single-hold release when the spear is fully cocked.
			_play_fire_haptic_if_fully_cocked(by)
			call_deferred("_restore_pickup_ref_after_blocked_let_go", by)
		else:
			call_deferred("_clear_pickup_ref_if_not_grabbing", by)
		return
	if current_state is SpearDoubleHoldState:
		var releasing_left := is_grab_left_handed(by)
		# The main grab point should not be able to release while double-held.
		if releasing_left == _primary_hold_is_left:
			call_deferred("_restore_pickup_ref_after_blocked_let_go", by)
			return
		else:
			# Tracker takeover edge-case:
			# logical secondary can be mapped as grab_driver.primary with no secondary entry.
			# If we call super.let_go in this shape, the whole pickable drops.
			if _grab_driver and _grab_driver.primary and _grab_driver.secondary == null:
				var by_grab := _grab_driver.get_grab(by)
				if by_grab and by_grab == _grab_driver.primary:
					_rebind_pickup_ownership_after_takeover_release(by)
					is_left_just_grabbed = _primary_hold_is_left
					change_state(SpearSingleHoldState.new())
					return
			is_left_just_grabbed = _primary_hold_is_left
			change_state(SpearSingleHoldState.new())
	
	var safe_lin: Vector3 = _sanitize_drop_linear_velocity(p_linear_velocity)
	super.let_go(by, safe_lin, p_angular_velocity)


func _restore_pickup_ref_after_blocked_let_go(pickup: Node3D) -> void:
	if not is_instance_valid(self) or not is_instance_valid(pickup):
		return
	if not is_picked_up():
		return
	if pickup is XRToolsFunctionPickup and (pickup as XRToolsFunctionPickup).picked_up_object != self:
		(pickup as XRToolsFunctionPickup).picked_up_object = self


func _clear_pickup_ref_if_not_grabbing(pickup: Node3D) -> void:
	if not is_instance_valid(pickup):
		return
	if pickup is XRToolsFunctionPickup:
		var fn := pickup as XRToolsFunctionPickup
		if fn.picked_up_object == self and (_grab_driver == null or _grab_driver.get_grab(pickup) == null):
			fn.picked_up_object = null


func _rebind_pickup_ownership_after_takeover_release(releasing_pickup: Node3D) -> void:
	var expected_main_pickup := _get_function_pickup_for_hand(_primary_hold_is_left)

	# Release physics ownership from the off-hand that asked to let go.
	if releasing_pickup is XRToolsFunctionPickup:
		var releasing_fn := releasing_pickup as XRToolsFunctionPickup
		if releasing_fn.picked_up_object == self:
			releasing_fn.picked_up_object = null

	# Keep the spear attached to the original main hand.
	if expected_main_pickup != null and expected_main_pickup.picked_up_object != self:
		expected_main_pickup.picked_up_object = self
	if expected_main_pickup != null:
		call_deferred("_ensure_grab_driver_has_main_pickup_after_takeover_release", expected_main_pickup)


func _get_function_pickup_for_hand(is_left_hand: bool) -> XRToolsFunctionPickup:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return null
	var expected_tracker := &"left_hand" if is_left_hand else &"right_hand"
	var nodes := scene.find_children("*", "XRToolsFunctionPickup", true, false)
	for node in nodes:
		if not (node is XRToolsFunctionPickup):
			continue
		var pickup := node as XRToolsFunctionPickup
		var controller := XRHelpers.get_xr_controller(pickup)
		if controller and controller.tracker == expected_tracker:
			return pickup
	return null


func _ensure_grab_driver_has_main_pickup_after_takeover_release(expected_main_pickup: XRToolsFunctionPickup) -> void:
	if not is_instance_valid(expected_main_pickup):
		return
	if not is_picked_up():
		return
	var has_main_grab := _grab_driver != null and _grab_driver.get_grab(expected_main_pickup) != null
	if not has_main_grab:
		super.pick_up(expected_main_pickup)
		_force_primary_to_main_grab_point_if_secondary(expected_main_pickup)


func _force_primary_to_main_grab_point_if_secondary(_expected_main_pickup: XRToolsFunctionPickup) -> void:
	if _grab_driver == null or _grab_driver.primary == null:
		return
	var expected_tracker := &"left_hand" if _primary_hold_is_left else &"right_hand"
	if _grab_driver.primary.controller == null or _grab_driver.primary.controller.tracker != expected_tracker:
		return
	var hand_point := _grab_driver.primary.hand_point
	if is_instance_valid(hand_point) and hand_point.mode == XRToolsGrabPointHand.Mode.SECONDARY:
		_grab_driver.primary.set_grab_point(main_grab)


func mark_windup_slide_baseline() -> void:
	# Used by SpearDoubleHoldState.enter() to prevent a first-frame windup spike.
	_windup_prev_slide_pos = current_slide_pos
	_windup_prev_slide_valid = true
	_windup_prev_cocked_01 = _compute_double_hold_cocked_01()
	_windup_prev_cocked_valid = true
	_windup_low_armed_double = true
	_windup_high_armed_double = true

func _reset_windup_audio() -> void:
	if _windup_player and _windup_player.playing:
		_windup_player.stop()

func _compute_double_hold_cocked_01() -> float:
	# Map `current_slide_pos` from [-0.8 .. 0.0] to [1 .. 0].
	# If the spear is near-neutral or beyond (positive slide), cocked stays at 0.
	var span := absf(_DOUBLE_HOLD_SLIDE_MIN_FOR_COCKED_01)
	if span <= 1e-6:
		return 0.0
	return clampf((-current_slide_pos) / span, 0.0, 1.0)

func _trigger_grab_haptics(amp: float, dur: float) -> void:
	var seen: Array[XRController3D] = []
	for gr in [_grab_driver.primary, _grab_driver.secondary]:
		if is_instance_valid(gr) and is_instance_valid(gr.by):
			var c := XRHelpers.get_xr_controller(gr.by)
			if c and not seen.has(c):
				seen.append(c)
				c.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)

func _check_double_hold_windup_haptics(prev_cocked_01: float, cur_cocked_01: float) -> void:
	if _windup_high_armed_double and prev_cocked_01 < windup_haptic_high_threshold and cur_cocked_01 >= windup_haptic_high_threshold:
		_trigger_grab_haptics(windup_haptic_high_amplitude, windup_haptic_high_duration)
		_windup_high_armed_double = false
	elif _windup_low_armed_double and prev_cocked_01 < windup_haptic_low_threshold and cur_cocked_01 >= windup_haptic_low_threshold:
		_trigger_grab_haptics(windup_haptic_low_amplitude, windup_haptic_low_duration)
		_windup_low_armed_double = false

	# Re-arm once the player slackens far enough.
	if cur_cocked_01 < windup_haptic_low_threshold - _WINDUP_REARM_HYSTERESIS:
		_windup_low_armed_double = true
	if cur_cocked_01 < windup_haptic_high_threshold - _WINDUP_REARM_HYSTERESIS:
		_windup_high_armed_double = true

func _compute_single_hold_cocked_01() -> float:
	# Single-hold uses the same "slide is negative when cocked" convention.
	return _compute_double_hold_cocked_01()

func _play_fire_haptic_if_fully_cocked(releasing_by: Node3D) -> void:
	var cocked_01 := _compute_single_hold_cocked_01()
	if cocked_01 < fire_haptic_min_cocked_01:
		return

	var denom := 1.0 - fire_haptic_min_cocked_01
	var t := 0.0 if denom <= 1.0e-6 else (cocked_01 - fire_haptic_min_cocked_01) / denom
	t = clampf(t, 0.0, 1.0)

	var amp := lerpf(fire_haptic_min_amplitude, fire_haptic_max_amplitude, t)
	var dur := lerpf(fire_haptic_min_duration, fire_haptic_max_duration, t)

	var rc := XRHelpers.get_xr_controller(releasing_by)
	if rc:
		rc.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)

func _update_windup_audio_from_slide_velocity(slide_velocity_m_s: float) -> void:
	if not _windup_player:
		return
	# In this spear setup, "pull back" corresponds to the slide position
	# moving in the negative direction (slide becoming more negative).
	# So we play the clip only when the slide velocity is negative.
	if not is_picked_up() or slide_velocity_m_s >= 0.0:
		_reset_windup_audio()
		return

	var stretch_speed_m_s := -slide_velocity_m_s # positive magnitude

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
	# Plays when slide is moving the "other" direction (positive slide velocity),
	# but at reduced volume/pitch.
	if not _windup_player:
		return
	if not is_picked_up() or slide_velocity_m_s <= 0.0:
		_reset_windup_audio()
		return

	var denom := windup_speed_for_max - windup_speed_for_min
	if denom <= 0.0:
		return

	var stretch_speed_m_s := slide_velocity_m_s # positive magnitude
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

	if current_state is SpearDoubleHoldState:
		if not _windup_prev_slide_valid:
			mark_windup_slide_baseline()
			return

		var slide_vel_m_s := (current_slide_pos - _windup_prev_slide_pos) / maxf(delta, 1.0e-6)
		_update_windup_audio_from_slide_velocity(slide_vel_m_s)
		_windup_prev_slide_pos = current_slide_pos
		if _windup_prev_cocked_valid:
			var cur_cocked_01 := _compute_double_hold_cocked_01()
			_check_double_hold_windup_haptics(_windup_prev_cocked_01, cur_cocked_01)
			_windup_prev_cocked_01 = cur_cocked_01
	elif current_state is SpearSingleHoldState:
		if not _windup_prev_slide_valid:
			mark_windup_slide_baseline()
			return

		var slide_vel_m_s := (current_slide_pos - _windup_prev_slide_pos) / maxf(delta, 1.0e-6)
		_windup_prev_cocked_valid = false

		# Single-hold: play normal rubber-band when pulling back (negative),
		# and quieter when returning/slackening (positive).
		if slide_vel_m_s < 0.0:
			_update_windup_audio_from_slide_velocity(slide_vel_m_s)
		elif slide_vel_m_s > 0.0:
			_update_quiet_windup_audio_from_reverse_slide_velocity(slide_vel_m_s)
		else:
			_reset_windup_audio()

		_windup_prev_slide_pos = current_slide_pos
	else:
		_windup_prev_slide_valid = false
		_windup_prev_cocked_valid = false
		_reset_windup_audio()

# THIS JUST SETS THE POSITION OF THE SPEAR
# ANIMATION IS UP TO INDIVIDUAL STATES
func set_main_hand_slide_position(slide_pos:float):
	var snap := _grab_driver.global_transform
	var shaft_world := snap.basis.y.normalized()

	# Represents a vector going up the spear
	var slip_dir := shaft_world
	# Sets the amount of movement
	var _shaft_slide_m = slide_pos-current_slide_pos
	# Moves the grip
	_grab_driver.global_transform = Transform3D(snap.basis, snap.origin+slip_dir*current_slide_pos+ slip_dir * _shaft_slide_m)
	# Moves the hand
	refresh_main_grab_lite_hands_slide_visual(slip_dir, current_slide_pos+_shaft_slide_m)

	current_slide_pos=slide_pos

func show_single_hold_hands(is_left_hand_leading: bool) -> void:
	if current_state is SpearCapturedState:
		return

	_sync_dynamic_band_hand_anchors(is_left_hand_leading)
	_set_mesh_visible(left_hand_main_grab_point_mesh, is_left_hand_leading)
	_set_mesh_visible(right_hand_main_grab_point_mesh, not is_left_hand_leading)
	_set_mesh_visible(left_hand_secondary_grab_point_mesh, false)
	_set_mesh_visible(right_hand_secondary_grab_point_mesh, false)

func hide_single_hold_hands(_is_left_hand_leading: bool) -> void:
	_set_mesh_visible(left_hand_main_grab_point_mesh, false)
	_set_mesh_visible(right_hand_main_grab_point_mesh, false)
	_set_mesh_visible(left_hand_secondary_grab_point_mesh, false)
	_set_mesh_visible(right_hand_secondary_grab_point_mesh, false)

func show_second_hand(is_left_hand_leading:bool)->void:
	var main_is_left = is_left_hand_leading
	var off_is_left = not is_left_hand_leading
	if _grab_driver and _grab_driver.primary and _grab_driver.primary.controller:
		main_is_left = _grab_driver.primary.controller.tracker == &"left_hand"
	if _grab_driver and _grab_driver.secondary and _grab_driver.secondary.controller:
		off_is_left = _grab_driver.secondary.controller.tracker == &"left_hand"
	var main_visible_left_mesh = not main_is_left
	var off_visible_left_mesh = not off_is_left

	_sync_dynamic_band_hand_anchors(main_visible_left_mesh)
	_set_mesh_visible(left_hand_main_grab_point_mesh, main_visible_left_mesh)
	_set_mesh_visible(right_hand_main_grab_point_mesh, not main_visible_left_mesh)
	_set_mesh_visible(left_hand_secondary_grab_point_mesh, off_visible_left_mesh)
	_set_mesh_visible(right_hand_secondary_grab_point_mesh, not off_visible_left_mesh)

func _sync_dynamic_band_hand_anchors(is_left_hand_leading: bool) -> void:
	for n in find_children("*", "CylinderConnector", true, false):
		if n is CylinderConnector:
			(n as CylinderConnector).use_left_hand_anchor(is_left_hand_leading)

func _set_mesh_visible(mesh_node: Node3D, is_vizibl: bool) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.visible = is_vizibl

## Returns true if the node 'by' is associated with the left hand tracker.
func is_grab_left_handed(by: Node3D) -> bool:
	var controller := XRHelpers.get_xr_controller(by)
	if controller:
		return controller.tracker == &"left_hand"
	
	push_error("Spear Pickable couldn't find controller on grab")
	# Fallback: Check if the name contains 'left' if the helper fails
	return "left" in by.name.to_lower()


func _shares_tracker_with_existing_grabs(by: Node3D) -> bool:
	var incoming := XRHelpers.get_xr_controller(by)
	if not incoming:
		return false
	if _grab_driver.primary and _grab_driver.primary.controller:
		if incoming.tracker == _grab_driver.primary.controller.tracker:
			return true
	if _grab_driver.secondary and _grab_driver.secondary.controller:
		if incoming.tracker == _grab_driver.secondary.controller.tracker:
			return true
	return false


func _is_stale_non_primary_grab_lock(by: Node3D) -> bool:
	if _grab_driver == null:
		return false
	var by_grab := _grab_driver.get_grab(by)
	if by_grab == null:
		return false
	# Only consider stale lock when in single-hold and by is the non-primary side.
	if not (current_state is SpearSingleHoldState):
		return false
	var by_left := is_grab_left_handed(by)
	if by_left == _primary_hold_is_left:
		return false
	# If by currently maps as primary in single-hold while logical primary side is opposite,
	# this is the takeover residue we want to recover from.
	if _grab_driver.primary and by_grab == _grab_driver.primary:
		return true
	return false
