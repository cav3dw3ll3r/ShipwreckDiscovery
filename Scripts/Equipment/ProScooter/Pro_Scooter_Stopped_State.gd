extends ProScooterState
class_name ProScooterStoppedState


func handle_click_pattern(click_count: int) -> void:
	if scooter == null or not is_instance_valid(scooter):
		return

	if scooter.reverse_mode != ProSeaScooterPickable.ReverseMode.NONE:
		if click_count >= 2:
			scooter.exit_reverse_mode()
		return

	match click_count:
		1:
			pass
		2:
			if scooter.forward_gear <= 0:
				scooter.start_forward_motor()
			else:
				scooter.shift_forward_gear(1)
		3:
			scooter.start_forward_motor_at_gear(scooter.jump_gear)
		4:
			scooter.enter_reverse_untangle()
		_:
			if click_count > 4:
				scooter.enter_reverse_untangle()
