class_name ProScooterState
extends RefCounted

var scooter: ProSeaScooterPickable


func enter(_scooter: ProSeaScooterPickable, _params: Dictionary = {}) -> void:
	scooter = _scooter


func tick(_delta: float) -> void:
	pass


func exit(_next_state: ProScooterState = null) -> void:
	pass


func handle_click_pattern(_click_count: int) -> void:
	pass
