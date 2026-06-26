extends Node3D
class_name MenuCursor


func _ready() -> void:
	hide()

func on_pointer_event(event: XRToolsPointerEvent):
	if event.event_type == XRToolsPointerEvent.Type.MOVED:
		global_position = event.position
	if event.event_type == XRToolsPointerEvent.Type.ENTERED:
		show()
	if event.event_type == XRToolsPointerEvent.Type.EXITED:
		hide()
