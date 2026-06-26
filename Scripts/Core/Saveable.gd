@tool
extends Node
class_name Saveable

@export var uuid: String

func _init():
	if uuid.is_empty():
		uuid = generate_uuid()

func _ready() -> void:
	SaveLoad.register_saveable(self)

static func generate_uuid() -> String:
	return str(randi()) + str(Time.get_unix_time_from_system())

func get_state() -> Dictionary:
	push_error("get_save_data() not implemented!")
	return {}

func restore_state(data: Dictionary):
	push_error("restore_state() not implemented!")
