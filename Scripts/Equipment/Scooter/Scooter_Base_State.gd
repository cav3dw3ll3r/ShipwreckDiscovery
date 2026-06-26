class_name ScooterState


var is_left_leading: bool
var scooter: SeaScooterPickable


func enter(_scooter: SeaScooterPickable, _params: Dictionary = {}) -> void:
	scooter = _scooter


func tick(_delta: float) -> void:
	pass


func exit(_next_state: ScooterState = null) -> void:
	pass


func is_trigger_pressed() -> bool:
	if scooter == null or not is_instance_valid(scooter):
		return false
	var controller := scooter.get_picked_up_by_controller()
	return (
		controller != null
		and controller.get_is_active()
		and controller.is_button_pressed("trigger")
	)
