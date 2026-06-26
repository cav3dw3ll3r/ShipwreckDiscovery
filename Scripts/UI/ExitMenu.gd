extends Node

@onready var exit_button: LocalizedButton = $VBoxContainer/Button

func _ready() -> void:
	if OS.has_feature("android"):
		exit_button.stringID = "exit_game_android"
		exit_button.refresh()

func onExit():
	SaveLoad.save_all()
	get_tree().quit()
