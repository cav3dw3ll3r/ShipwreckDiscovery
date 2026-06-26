extends ScooterState
class_name ScooterRampDownState


var _elapsed: float = 0.0
var _start_power: float = 0.0


func enter(_scooter: SeaScooterPickable, _params: Dictionary = {}) -> void:
	super.enter(_scooter)
	_elapsed = 0.0
	_start_power = scooter.power


func tick(delta: float) -> void:
	if scooter == null or not is_instance_valid(scooter) or not scooter.is_picked_up():
		return

	if is_trigger_pressed():
		scooter.change_state(ScooterRampUpState.new(), {"from_power": scooter.power})
		return

	_elapsed += delta
	var ramp_sec: float = scooter.ramp_down_seconds
	var t: float = 1.0 if ramp_sec <= 0.0 else clampf(_elapsed / ramp_sec, 0.0, 1.0)
	scooter.power = lerpf(_start_power, 0.0, t)

	if t >= 1.0:
		scooter.change_state(ScooterIdleState.new())
