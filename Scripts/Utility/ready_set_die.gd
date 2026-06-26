extends Node

## When true, collision/visual mesh stays alive until WreckDynamicPlacer finishes scatter.
@export var wait_for_dynamic_placement: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if wait_for_dynamic_placement:
		add_to_group("static_wreck_geometry")
	else:
		queue_free()
