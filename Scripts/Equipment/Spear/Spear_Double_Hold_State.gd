extends SpearState
class_name SpearDoubleHoldState

## Below this separation (meters), spear shaft [code]basis.y[/code] tracks primary controller +Y fully.
const CLOSE_BLEND_M: float = 0.1
## At or above this separation (meters), shaft aims along the vector between hands (classic double-hold).
const FAR_BLEND_M: float = 0.35
const HAND_AXIS_EPS: float = 1e-3

## Shaft +Y locked at enter from single-hold spear basis (not per-tick grab_driver).
var _shaft_y_ref: Vector3 = Vector3.UP
## When the physical hand line opposes single-hold +Y, keep that flip for the whole state.
var _invert_y_hand_line: bool = false
var _ref_basis_at_enter: Basis = Basis.IDENTITY

# Reference length: the "natural" distance between hands when the spear isn't cocked.
# If your hands are 0.5m apart when you first grab, this is your baseline.
var _initial_hand_dist: float = 0.918

func enter(_spear: RevisedSpearPickable, _params: Dictionary = {}) -> void:
	spear = _spear
	is_left_leading = spear._primary_hold_is_left
	spear.show_second_hand(is_left_leading)

	# Optional: Capture the current distance as the 'rest' position
	var p: Vector3 = spear._grab_driver.primary.controller.global_position
	var s: Vector3 = spear._grab_driver.secondary.controller.global_position
	_initial_hand_dist = p.distance_to(s)
	var _pre_basis_y := spear.global_basis.y
	_ref_basis_at_enter = spear.global_basis
	_shaft_y_ref = _pre_basis_y.normalized()
	_invert_y_hand_line = false
	if _initial_hand_dist > HAND_AXIS_EPS:
		var _y_raw_enter := (s - p) / _initial_hand_dist
		_invert_y_hand_line = _y_raw_enter.dot(_shaft_y_ref) < 0.0
	tick(0.)
	spear.snapshot_main_grab_lite_hand_local_rest()
	spear.mark_windup_slide_baseline()


func _xr_pickable_origin(primary: Grab) -> Vector3:
	if primary.by:
		return (primary.by.global_transform * primary.transform.inverse()).origin
	if primary.controller:
		return primary.controller.global_position
	return Vector3.ZERO


func _build_shaft_basis(shaft_y: Vector3) -> Basis:
	# Re-orthonormalize Y while preserving roll from enter (prevents windback twist spin).
	var y_axis := shaft_y.normalized()
	var ref_x := _ref_basis_at_enter.x
	var x_axis := ref_x - y_axis * y_axis.dot(ref_x)
	if x_axis.length_squared() < HAND_AXIS_EPS * HAND_AXIS_EPS:
		var ref_z := _ref_basis_at_enter.z
		x_axis = ref_z - y_axis * y_axis.dot(ref_z)
	if x_axis.length_squared() < HAND_AXIS_EPS * HAND_AXIS_EPS:
		x_axis = y_axis.cross(Vector3.UP)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	x_axis = z_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func tick(_delta: float) -> void:
	if not spear or not spear._grab_driver:
		return

	var primary: Grab = spear._grab_driver.primary
	var secondary: Grab = spear._grab_driver.secondary
	
	if not primary or not secondary:
		return

	# 1. Capture World Positions (secondary still uses controller for hand-line axis)
	var anchor_pos: Vector3 = _xr_pickable_origin(primary)
	var origin_pos: Vector3 = primary.controller.global_position if primary.controller else anchor_pos
	var target_pos: Vector3 = secondary.controller.global_position
	var current_dist: float = origin_pos.distance_to(target_pos)
	# 2. Logic: Cocking / Sliding Projection
	if not spear.is_primary_hand_grip_engaged():
		var raw_slide: float = current_dist - _initial_hand_dist
		spear.current_slide_pos = clampf(raw_slide, -0.8, 0.1)

	# 3. Calculate Basis (The Spear's Master Orientation)
	var y_between: Vector3
	if current_dist > HAND_AXIS_EPS:
		y_between = (target_pos - origin_pos) / current_dist
	else:
		y_between = primary.controller.global_basis.y.normalized()
	# Hand-line sign locked at enter (stable) + shaft ref locked from pre-transition basis.
	if _invert_y_hand_line:
		y_between = -y_between
	var y_main: Vector3 = primary.controller.global_basis.y.normalized()
	var denom: float = FAR_BLEND_M - CLOSE_BLEND_M
	var t_main: float = clampf((FAR_BLEND_M - current_dist) / denom, 0.0, 1.0)
	var new_y: Vector3 = y_between.lerp(y_main, t_main)
	if new_y.length_squared() < HAND_AXIS_EPS * HAND_AXIS_EPS:
		new_y = y_main
	else:
		new_y = new_y.normalized()

	var alt_basis_without_hand_aim = _build_shaft_basis(new_y)
	var final_basis: Basis = alt_basis_without_hand_aim
	var shaft_y: Vector3 = final_basis.y.normalized()

	# Match XRToolsGrabDriver pickable origin, then apply shaft slide + glove counter-shift.
	var dest_origin: Vector3 = anchor_pos + (shaft_y * spear.current_slide_pos)
	if is_instance_valid(spear._grab_driver):
		spear._grab_driver.global_transform = Transform3D(final_basis, dest_origin)
		spear._grab_driver.force_update_transform()
		if is_instance_valid(spear):
			spear.force_update_transform()
	spear.refresh_main_grab_lite_hands_slide_visual(shaft_y, spear.current_slide_pos)

func exit(_next_state: SpearState = null) -> void:
	if is_instance_valid(spear):
		# 1. FINAL TRANSFORM SYNC
		# Before we hand control back, ensure the main grab point is 
		# mathematically aligned with the spear's current physical position.
		# This prevents the 'snap' back to a stale grab position.
		spear.set_main_hand_slide_position(spear.current_slide_pos)

		# 2. VISUAL RESET
		# Instantly reset the Lite Hand offsets. This snaps the hand meshes
		# back to the controller anchors so they don't appear to 'fly away' 
		# when the secondary hand is released.
		spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)
		
		# 3. STATE HANDOFF
		# Explicitly update the 'slide_accum_m' or equivalent in the main script
		# so the rubber-band logic in SingleHold starts with clean data.
		if spear.has_method("sync_state_handoff"):
			spear.sync_state_handoff()

	# Clear reference
	spear = null
