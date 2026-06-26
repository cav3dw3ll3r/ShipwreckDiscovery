extends Node3D

@onready var player = get_tree().get_first_node_in_group("Player")

func _ready() -> void:
	call_deferred("calibrate")

func calibrate():
	global_position.y = player.global_position.y
