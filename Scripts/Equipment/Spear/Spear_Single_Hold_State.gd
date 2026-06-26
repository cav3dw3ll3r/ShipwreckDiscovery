extends SpearState
class_name SpearSingleHoldState

## Higher [code]RUBBER_SPRING_K[/code] settles [code]current_slide_pos[/code] toward home faster; higher [code]RUBBER_DAMPING_C[/code] reduces overshoot.
const RUBBER_HOME_SLIDE_POS := 0.0
const RUBBER_MASS := 1.0
const RUBBER_SPRING_K := 500.0
const RUBBER_DAMPING_C := 20.0
const RUBBER_MAX_SLIDE_SPEED := 4.0
const RUBBER_MAX_SLIDE_ACCEL := 120.0

## Axial slip velocity (m/s) along spear shaft while loose grip; integrates in [method rubber_band_sim].
var _rubber_slide_vel: float = 0.0

## Cumulative slip (meters) along shaft axis toward gravity while loose grip.
var _shaft_slide_m: float = 0.0


func enter(_spear: RevisedSpearPickable, _params = {}):
	spear = _spear
	is_left_leading = spear.is_left_just_grabbed
	_shaft_slide_m = 0.0
	_rubber_slide_vel = 0.0

	var mg: XRToolsGrabPoint = spear.main_grab
	mg.enabled = false
	spear.show_single_hold_hands(is_left_leading)
	spear.snapshot_main_grab_lite_hand_local_rest()
	spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)


func tick(delta: float):
	var s := spear
	if s == null or not is_instance_valid(s) or not s.is_picked_up():
		return

	if s.is_primary_hand_grip_engaged():
		_rubber_slide_vel = 0.0
		spear.set_main_hand_slide_position(spear.current_slide_pos)
		return

	rubber_band_sim(delta)


func rubber_band_sim(delta: float) -> void:
	var x := spear.current_slide_pos
	var v := _rubber_slide_vel
	var disp := x - RUBBER_HOME_SLIDE_POS
	
	# 1. NONLINEAR SPRING CALCULATION
	# Raising disp to the power of 2 (preserving sign) makes the force
	# exponentially stronger the further back it is pulled.
	var disp_abs = abs(disp)
	var force_multiplier = 1.0 + (disp_abs * 5.0) # Increases stiffness with stretch
	
	# Alternatively, use a power function for a 'snappier' release:
	# force = K * sign(disp) * (abs(disp) ^ 1.5)
	
	var spring_force = -RUBBER_SPRING_K * disp * force_multiplier
	var damping_force := -RUBBER_DAMPING_C * v
	
	var raw_accel = (spring_force + damping_force) / RUBBER_MASS
	
	# 2. ACCELERATION CAP
	# Bumping this limit up allows for that 'instant' snap on frame 1
	var accel := clampf(raw_accel, -250.0, 250.0)
	
	v += accel * delta
	v = clampf(v, -12.0, 12.0) # Increase max speed for the 'zip' effect
	
	var x_new := x + v * delta
	spear.set_main_hand_slide_position(x_new)
	_rubber_slide_vel = v

func exit(_next_state: SpearState = null):
	_shaft_slide_m = 0.0
	_rubber_slide_vel = 0.0
	if spear != null and is_instance_valid(spear):
		spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)
	if spear == null or not is_instance_valid(spear):
		return
	if not spear.is_picked_up():
		var mg: XRToolsGrabPoint = spear.main_grab
		if is_instance_valid(mg):
			mg.enabled = true
