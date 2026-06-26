extends ProScooterState
class_name ProScooterForwardState


func handle_click_pattern(click_count: int) -> void:
	if scooter == null or not is_instance_valid(scooter):
		return

	match click_count:
		1:
			scooter.shift_forward_gear(-1)
		2:
			scooter.shift_forward_gear(1)
		3:
			scooter.set_forward_gear_and_run(scooter.jump_gear)
		4:
			scooter.enter_reverse_untangle()
		_:
			if click_count > 4:
				scooter.enter_reverse_untangle()
