class_name AmateurSpearHoldState

const RUBBER_HOME_SLIDE_POS := 0.0
const RUBBER_MASS := 1.0
const RUBBER_SPRING_K := 500.0
const RUBBER_DAMPING_C := 20.0
const COCKED_SLIDE_MIN := -0.8

var spear: AmateurSpearPickable
var is_left_leading: bool

var _rubber_slide_vel: float = 0.0
var _was_trigger_pressed: bool = false


func enter(p_spear: AmateurSpearPickable, _params: Dictionary = {}) -> void:
	spear = p_spear
	is_left_leading = spear.is_left_just_grabbed
	_rubber_slide_vel = 0.0
	_was_trigger_pressed = spear.is_dominant_trigger_pressed()

	var mg: XRToolsGrabPoint = spear.main_grab
	mg.enabled = false
	spear.show_single_hold_hands(is_left_leading)
	spear.snapshot_main_grab_lite_hand_local_rest()
	spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)


func tick(delta: float) -> void:
	if spear == null or not is_instance_valid(spear) or not spear.is_picked_up():
		return

	var trigger_pressed := spear.is_dominant_trigger_pressed()
	if not _was_trigger_pressed and trigger_pressed:
		pass
	elif _was_trigger_pressed and not trigger_pressed:
		spear.play_fire_haptic_if_fully_cocked()

	_was_trigger_pressed = trigger_pressed

	if trigger_pressed:
		_rubber_slide_vel = 0.0
		var target := COCKED_SLIDE_MIN
		var next := move_toward(spear.current_slide_pos, target, spear.trigger_cock_slide_speed_mps * delta)
		spear.set_main_hand_slide_position(next)
	else:
		rubber_band_sim(delta)


func rubber_band_sim(delta: float) -> void:
	var x := spear.current_slide_pos
	var v := _rubber_slide_vel
	var disp := x - RUBBER_HOME_SLIDE_POS

	var disp_abs := absf(disp)
	var force_multiplier := 1.0 + (disp_abs * 5.0)
	var spring_force := -RUBBER_SPRING_K * disp * force_multiplier
	var damping_force := -RUBBER_DAMPING_C * v
	var raw_accel := (spring_force + damping_force) / RUBBER_MASS
	var accel := clampf(raw_accel, -250.0, 250.0)

	v += accel * delta
	v = clampf(v, -12.0, 12.0)

	var x_new := x + v * delta
	spear.set_main_hand_slide_position(x_new)
	_rubber_slide_vel = v


func exit(_next_state: AmateurSpearHoldState = null) -> void:
	_rubber_slide_vel = 0.0
	if spear != null and is_instance_valid(spear):
		spear.refresh_main_grab_lite_hands_slide_visual(Vector3.ZERO, 0.0)
	if spear == null or not is_instance_valid(spear):
		return
	if not spear.is_picked_up():
		var mg: XRToolsGrabPoint = spear.main_grab
		if is_instance_valid(mg):
			mg.enabled = true
	spear = null
