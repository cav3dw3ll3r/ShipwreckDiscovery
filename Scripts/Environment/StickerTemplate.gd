extends Node3D
class_name StickerTemplate

@export var is_large_sticker = false

func _ready() -> void:
	# Clear out any old children
	for child in get_children():
		child.queue_free()
