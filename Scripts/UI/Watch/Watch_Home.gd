extends Control

var previous:PackedScene = preload("res://Prefabs/UI/WatchSubMenus/top_level_menu.tscn")

@onready var respawn_button:Button = $VBoxContainer/Respawn
@onready var quit_button:Button = $VBoxContainer/QuitToDesktop
@onready var back_button:Button = $VBoxContainer/Back

func _ready() -> void:
	back_button.pressed.connect(on_back)
	quit_button.pressed.connect(quit)
	respawn_button.pressed.connect(respawn)

func respawn():
	var player = get_tree().get_first_node_in_group("Player")
	var player_SM = player.get_parent().get_node("PlayerStateMachine")
	player_SM.respawn()
	pass

func quit():
	SaveLoad.save_all()
	get_tree().quit()

func on_back():
	var spawn = previous.instantiate()
	get_parent().add_child(spawn)
	queue_free()
