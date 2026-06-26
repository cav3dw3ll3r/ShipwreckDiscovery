extends Node

@export var anim_name:String
@export var player:AnimationPlayer

func _ready() -> void:
	player.play(anim_name)
