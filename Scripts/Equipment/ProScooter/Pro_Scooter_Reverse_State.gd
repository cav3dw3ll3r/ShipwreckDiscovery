extends ProScooterState
class_name ProScooterReverseState


func handle_click_pattern(click_count: int) -> void:
	if scooter == null or not is_instance_valid(scooter):
		return

	# Paused reverse: double-click exits to forward (manual). While holding, double-click shifts speed.
	if click_count >= 2 and not scooter._is_trigger_held():
		scooter.exit_reverse_mode()
		return

	match click_count:
		1:
			scooter.set_reverse_mode(ProSeaScooterPickable.ReverseMode.UNTANGLE)
		2:
			scooter.set_reverse_mode(ProSeaScooterPickable.ReverseMode.REVERSE)
		_:
			pass
