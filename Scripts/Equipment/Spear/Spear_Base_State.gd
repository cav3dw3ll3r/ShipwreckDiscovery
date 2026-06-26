class_name SpearState


var is_left_leading:bool
var spear:RevisedSpearPickable

func enter(_spear: RevisedSpearPickable, _params: Dictionary = {}) -> void:
	spear = _spear

func tick(_delta: float): pass
func exit(_next_state: SpearState = null): pass
