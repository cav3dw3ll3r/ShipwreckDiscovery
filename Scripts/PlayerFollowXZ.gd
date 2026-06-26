extends Node3D

@onready var player = get_tree().get_first_node_in_group("Player")


func _process(delta: float) -> void:
	position.x = player.global_position.x
	position.z = player.global_position.z
