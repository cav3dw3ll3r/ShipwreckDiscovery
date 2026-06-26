extends SpearState
class_name SpearCapturedState

const EXIT_REAR_EPS_M: float = -0.05
const SNAG_HYSTERESIS_M: float = 0.002
## Dwell on snag "wall" before reparenting (fish stays at snag plane; spear keeps retracting).
const SLIDE_TOTAL_M: float = 0.35
const SLIDE_SPEED_MPS: float = 0.45

# Dynamic Tracking
var _zookeeper: ZookeeperPickable = null
var _mouth_target: Node3D = null
var _snag_target: Node3D = null
var _axis_end_target: Node3D = null

# Geometry & Offsets
var _initial_hand_offset_m: float = 0.0
var _spear_tip_offset_m: float = 0.0

# WIZARD TWEAK: Adjust this Vector3 to perfectly center the spear in the visual tube
# (e.g., Vector3(0, 0, 0.02) to nudge it 2cm forward)
var _visual_center_offset: Vector3 = Vector3(0,0,-0.135)

## Subtracted from max axial tip depth (mouth → axis end along tube) so the spear stops slightly inside the mesh (m).
## Tune here; this state is constructed in code so it is not an inspector export.
var hard_stop_margin_m: float = 0.02

## Snag plane depth along tube axis (m) + this; positive = deeper into tube.
var snag_captured_fish_axial_nudge_m: float = 0.0

# State Flags
var _has_snagged: bool = false
var _is_completing: bool = false
var _fish_in_zookeeper: bool = false
var _slide_active: bool = false
var _slide_progress: float = 0.0
var _prev_tip_depth: float = 0.0
## Skip one tip-velocity sample so squish audio does not spike on the first capture frame.
var _zk_tip_audio_initialized: bool = false
## Fish held at snag plane in zookeeper local space while spear pulls back through it.
var _fish_locked_local_under_zk: Vector3 = Vector3.ZERO

func enter(_spear: RevisedSpearPickable, _params = {}):
	spear = _spear
	is_left_leading = spear.is_left_just_grabbed
	
	_zookeeper = _params.get("zookeeper")
	_mouth_target = _params.get("mouth_target")
	_snag_target = _params.get("snag_target")
	_axis_end_target = _params.get("axis_end_target")
	
	_has_snagged = false
	_is_completing = false
	_fish_in_zookeeper = false
	_slide_active = false
	_slide_progress = 0.0
	_prev_tip_depth = 0.0
	_zk_tip_audio_initialized = false

	# Calculate internal spear offset (from grip/origin to the literal tip)
	var tip = spear.get_node_or_null("Tip")
	_spear_tip_offset_m = tip.position.y if tip else 0.5

	# Calculate exactly where the player's hand is relative to the tube at the moment of entry
	var origin_and_axis = _get_current_tube_geometry()
	_initial_hand_offset_m = _get_hand_depth(origin_and_axis[0], origin_and_axis[1])

	# Visual Polish
	var mg: XRToolsGrabPoint = spear.main_grab
	if is_instance_valid(mg):
		mg.enabled = false
	spear.snapshot_main_grab_lite_hand_local_rest()
	spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)

	if is_instance_valid(_zookeeper):
		_zookeeper.reset_capture_squish_audio()

func tick(delta: float):
	if not is_instance_valid(spear) or not spear.is_picked_up() or not is_instance_valid(_zookeeper):
		return

	if _is_completing:
		return # Wait for transition

	# Update Tube geometry dynamically because the Tube can move
	var geo = _get_current_tube_geometry()
	var tube_origin: Vector3 = geo[0]
	var tube_axis: Vector3 = geo[1]
	
	var total_tube_depth = _axis_end_target.global_position.distance_to(tube_origin) if is_instance_valid(_axis_end_target) else 0.25
	var snag_axial_depth_m: float = _snag_axial_depth_m(tube_origin, tube_axis, total_tube_depth)

	# How far has the player pushed their hand down the axis since entering?
	var current_hand_depth = _get_hand_depth(tube_origin, tube_axis)
	var current_tip_depth = current_hand_depth - _initial_hand_offset_m

	if is_instance_valid(_axis_end_target):
		var max_tip_depth: float = (_axis_end_target.global_position - tube_origin).dot(tube_axis) - hard_stop_margin_m
		if max_tip_depth > 0.0:
			current_tip_depth = minf(current_tip_depth, max_tip_depth)

	if _zk_tip_audio_initialized:
		var tip_axial_vel_m_s = (current_tip_depth - _prev_tip_depth) / maxf(delta, 1.0e-6)
		_zookeeper.update_capture_squish_from_tip_axial_velocity(tip_axial_vel_m_s)
	else:
		_zookeeper.reset_capture_squish_audio()
		_zk_tip_audio_initialized = true

	# 1. Check Exit / Pull Out Condition
	if current_tip_depth < EXIT_REAR_EPS_M:
		if not _fish_in_zookeeper and _has_snagged:
			_complete_trophy_transfer()
		if _fish_in_zookeeper:
			_process_completion()
		else:
			_abort_to_loaded()
		_prev_tip_depth = current_tip_depth
		return

	# 2. Master Constraints: Lock Spear to Tube
	spear.global_basis = _align_basis_to_axis(tube_axis)

	var origin_depth = current_tip_depth - _spear_tip_offset_m
	spear.global_position = tube_origin + (tube_axis * origin_depth)
	
	# 3. Update Visuals
	spear.refresh_main_grab_lite_hands_slide_visual(tube_axis, spear.current_slide_pos)

	# 4. Forward past snag plane (deeper into tube) — record valid plunge; do not remove trophy
	if current_tip_depth >= snag_axial_depth_m and not _has_snagged:
		_has_snagged = true
		_on_snag_forward_haptic()

	# 5. Retract back through snag plane — fish catches on wall; lock at snag (spear keeps moving out)
	if _has_snagged and not _fish_in_zookeeper and not _slide_active:
		if _prev_tip_depth >= snag_axial_depth_m and current_tip_depth < snag_axial_depth_m - SNAG_HYSTERESIS_M:
			_begin_fish_slide(tube_origin, tube_axis)

	# 6. Fish stays on snag plane; timer then reparents (no ride toward funnel mouth)
	if _slide_active and not _fish_in_zookeeper:
		_tick_fish_slide(delta)

	# 7. Shader squish: axial depth in tube, gated along capture_insertion_axial_gate_* before shader remap_min/max.
	if not _fish_in_zookeeper:
		var trophy := _find_trophy_node()
		if trophy != null:
			var axial := _trophy_axial_insertion_fraction(trophy, tube_origin, tube_axis, total_tube_depth)
			var ins := _insertion_internal_from_axial_gated(axial)
			_poke_trophy_insertion(trophy, ins)

	_prev_tip_depth = current_tip_depth

func exit(_next_state: SpearState = null):
	var zk: ZookeeperPickable = _zookeeper
	_zookeeper = null
	if is_instance_valid(zk):
		zk.reset_capture_squish_audio()
	_is_completing = false
	_has_snagged = false
	_fish_in_zookeeper = false
	_slide_active = false
	_slide_progress = 0.0
	_fish_locked_local_under_zk = Vector3.ZERO
	if is_instance_valid(spear):
		spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)
		if not spear.is_picked_up():
			var mg: XRToolsGrabPoint = spear.main_grab
			if is_instance_valid(mg):
				mg.enabled = true

# --- Geometry Helpers ---

func _get_current_tube_geometry() -> Array:
	var raw_origin = _mouth_target.global_position if is_instance_valid(_mouth_target) else _zookeeper.global_position
	
	# Apply the visual offset in the Zookeeper's local space to shift the math rail
	var local_offset = _zookeeper.global_transform.basis * _visual_center_offset
	var offset_origin = raw_origin + local_offset
	
	var axis = (-_zookeeper.global_basis.y).normalized()
	return [offset_origin, axis]

func _get_hand_depth(tube_origin: Vector3, tube_axis: Vector3) -> float:
	var fn = spear.get_primary_function_pickup()
	var hand_pos = fn.global_position if is_instance_valid(fn) else spear.global_position
	return (hand_pos - tube_origin).dot(tube_axis)

func _align_basis_to_axis(axis: Vector3) -> Basis:
	var y = axis.normalized()
	var ref_x = spear.global_basis.x.normalized()

	if abs(y.dot(ref_x)) > 0.98:
		ref_x = spear.global_basis.z.normalized()

	var z = y.cross(ref_x).normalized()
	var x = z.cross(y).normalized()

	z = -z

	return Basis(x, y, z)


func _snag_axial_depth_m(tube_origin: Vector3, tube_axis: Vector3, total_tube_depth_fallback_m: float) -> float:
	var ax := tube_axis.normalized()
	if is_instance_valid(_snag_target):
		return (_snag_target.global_position - tube_origin).dot(ax)
	return total_tube_depth_fallback_m * 0.65

# --- Trophy / slide ---

func _find_trophy_node() -> Node3D:
	var from_ref := spear.get_spear_trophy()
	if from_ref != null:
		return from_ref
	var tip: Node = spear.get_node_or_null("Tip")
	if tip == null:
		return null
	var fallback: Node3D = null
	for child in tip.get_children():
		if not is_instance_valid(child) or not (child is Node3D):
			continue
		if String(child.name) == "SpearTipCaptureArea" or String(child.name) == "AudioStreamPlayer3D":
			continue
		var n3 := child as Node3D
		if n3.is_in_group("spear_trophy"):
			return n3
		if fallback == null:
			fallback = n3
	return fallback


func _begin_fish_slide(tube_origin: Vector3, tube_axis: Vector3) -> void:
	var t := _find_trophy_node()
	if t == null:
		return
	_slide_active = true
	_slide_progress = 0.0
	_arm_fish_wall_lock_at_snag(t, tube_origin, tube_axis)


func _arm_fish_wall_lock_at_snag(trophy: Node3D, tube_origin: Vector3, tube_axis: Vector3) -> void:
	var ax := tube_axis.normalized()
	var total_fb := _axis_end_target.global_position.distance_to(tube_origin) if is_instance_valid(_axis_end_target) else 0.25
	var snag_d: float = _snag_axial_depth_m(tube_origin, tube_axis, total_fb) + snag_captured_fish_axial_nudge_m
	var p0 := trophy.global_position
	var radial := p0 - tube_origin - ax * ((p0 - tube_origin).dot(ax))
	var world_lock := tube_origin + ax * snag_d + radial
	_fish_locked_local_under_zk = _zookeeper.global_transform.affine_inverse() * world_lock


func _tick_fish_slide(delta: float) -> void:
	var t := _find_trophy_node()
	if t == null:
		_slide_active = false
		return
	var world_lock := _zookeeper.global_transform * _fish_locked_local_under_zk
	t.global_position = world_lock
	_slide_progress = minf(1.0, _slide_progress + (SLIDE_SPEED_MPS / SLIDE_TOTAL_M) * delta)
	if _slide_progress >= 1.0:
		_attach_trophy_to_zookeeper(t)


func _complete_trophy_transfer() -> void:
	var t := _find_trophy_node()
	if t == null:
		return
	if not _slide_active:
		var geo := _get_current_tube_geometry()
		_arm_fish_wall_lock_at_snag(t, geo[0], geo[1])
	_slide_progress = 1.0
	if is_instance_valid(t):
		t.global_position = _zookeeper.global_transform * _fish_locked_local_under_zk
	_attach_trophy_to_zookeeper(t)


func _insertion_internal_from_axial_gated(axial_frac: float) -> float:
	if not is_instance_valid(spear):
		return axial_frac
	var a: float = spear.capture_insertion_axial_gate_begin
	var b: float = spear.capture_insertion_axial_gate_full
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var af := clampf(axial_frac, 0.0, 1.0)
	if af <= lo:
		return 0.0
	if af >= hi:
		return 1.0
	return inverse_lerp(lo, hi, af)


func _trophy_axial_insertion_fraction(trophy: Node3D, tube_origin: Vector3, tube_axis: Vector3, total_tube_depth_fallback_m: float) -> float:
	var ax := tube_axis.normalized()
	var max_insert_m: float = 0.0
	if is_instance_valid(_axis_end_target):
		max_insert_m = (_axis_end_target.global_position - tube_origin).dot(ax) - hard_stop_margin_m
	if max_insert_m <= 1e-4:
		var snag_d: float = _snag_axial_depth_m(tube_origin, tube_axis, total_tube_depth_fallback_m)
		max_insert_m = maxf(snag_d, 1e-4)
	var fish_along := (trophy.global_position - tube_origin).dot(ax)
	return clampf(fish_along / max_insert_m, 0.0, 1.0)


func _poke_trophy_insertion(trophy: Node3D, insertion: float) -> void:
	if not trophy.has_method("set_insertion_progress"):
		return
	var t := clampf(insertion, 0.0, 1.0)
	var mn := 0.0
	var mx := 1.0
	if is_instance_valid(spear):
		mn = spear.capture_insertion_progress_remap_min
		mx = spear.capture_insertion_progress_remap_max
	trophy.call("set_insertion_progress", lerpf(mn, mx, t))


func _attach_trophy_to_zookeeper(trophy: Node3D) -> void:
	if _fish_in_zookeeper or not is_instance_valid(_zookeeper):
		return
	_poke_trophy_insertion(trophy, 1.0)
	var parent_nd := _zookeeper.get_captured_fish_parent()
	if parent_nd == null:
		parent_nd = _zookeeper
	var xf := trophy.global_transform
	trophy.reparent(parent_nd, true)
	trophy.global_transform = xf
	trophy.add_to_group(DeadLionfish.GROUP_SPEAR_TROPHY_CAGED)

	_fish_in_zookeeper = true
	_slide_active = false
	spear.clear_spear_trophy_reference_after_tip_transfer()
	var tip: Node = spear.get_node_or_null("Tip")
	if tip:
		tip.set("is_probing", true)


func _on_snag_forward_haptic() -> void:
	var fn := spear.get_primary_function_pickup()
	if fn == null:
		return
	var c := XRHelpers.get_xr_controller(fn)
	if c and c.get_is_active():
		c.trigger_haptic_pulse("haptic", 0.0, 0.85, 0.12, 0.0)

# --- State Transitions ---

func _process_completion():
	_is_completing = true
	if is_instance_valid(_zookeeper):
		_zookeeper.finalize_capture()
	spear.change_state(SpearSingleHoldState.new())

func _abort_to_loaded():
	if is_instance_valid(_zookeeper):
		_zookeeper.reset_receptacle()
	spear.change_state(SpearLoadedState.new())
