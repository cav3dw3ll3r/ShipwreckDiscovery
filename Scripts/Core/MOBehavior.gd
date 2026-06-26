@icon("res://Images/CustomUI/PropsIcon.png")

extends Resource
class_name MOBehavior


@export var blend_factor: float = 1.0

# - OVERRIDE THESE -
func start(owner:Node3D) -> void:
	push_error("Do not use MOBehavior by itself - extend it!")

func compute(owner:Node3D,delta:float) -> void:
	push_error("Do not use MOBehavior by itself - extend it!")

func stop(owner:Node3D) -> void:
	push_error("Do not use MOBehavior by itself - extend it!")
