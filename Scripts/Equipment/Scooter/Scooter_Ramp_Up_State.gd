extends ScooterState
class_name ScooterRampUpState


var _elapsed: float = 0.0
var _start_power: float = 0.0


func enter(_scooter: SeaScooterPickable, params: Dictionary = {}) -> void:
	super.enter(_scooter)
	_elapsed = 0.0
	_start_power = params.get("from_power", scooter.power)


func tick(delta: float) -> void:
	if scooter == null or not is_instance_valid(scooter) or not scooter.is_picked_up():
		return

	if not is_trigger_pressed():
		scooter.change_state(ScooterRampDownState.new())
		return

	_elapsed += delta
	var ramp_sec: float = scooter.ramp_up_seconds
	var t: float = 1.0 if ramp_sec <= 0.0 else clampf(_elapsed / ramp_sec, 0.0, 1.0)
	scooter.power = lerpf(_start_power, 1.0, t)

	if t >= 1.0:
		scooter.change_state(ScooterSteadyState.new())
