extends ScooterState
class_name ScooterSteadyState


func enter(_scooter: SeaScooterPickable, _params: Dictionary = {}) -> void:
	super.enter(_scooter)
	scooter.power = 1.0


func tick(_delta: float) -> void:
	if scooter == null or not is_instance_valid(scooter) or not scooter.is_picked_up():
		return
	if not is_trigger_pressed():
		scooter.change_state(ScooterRampDownState.new())
