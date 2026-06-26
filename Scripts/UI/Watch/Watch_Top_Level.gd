extends Control

var home_menu = preload("res://Prefabs/UI/WatchSubMenus/home_menu.tscn")
var player_info_menu = preload("res://Prefabs/UI/WatchSubMenus/player_info_menu.tscn")
var scanner_menu = preload("res://Prefabs/UI/WatchSubMenus/scanner_menu.tscn")
var dive_ctrl_menu = preload("res://Prefabs/UI/WatchSubMenus/dive_control.tscn")

@onready var home_button = $TextureRect/Home
@onready var player_info_button = $TextureRect/PlayerInfo
@onready var scanner_button = $TextureRect/Scanner
@onready var dive_ctrl_button = $TextureRect/DiveCtrl

func _ready() -> void:
	home_button.pressed.connect(open_home_menu)
	#player_info_button.pressed.connect(open_PI_menu)
	scanner_button.pressed.connect(open_scanner)
	#dive_ctrl_button.pressed.connect(open_DC_menu)

func open_scanner():
	var menu_to_spawn = scanner_menu.instantiate()
	get_parent().add_child(menu_to_spawn)
	queue_free()

func open_home_menu():
	var menu_to_spawn = home_menu.instantiate()
	get_parent().add_child(menu_to_spawn)
	queue_free()

func open_PI_menu():
	var menu_to_spawn = player_info_menu.instantiate()
	get_parent().add_child(menu_to_spawn)
	queue_free()

func open_DC_menu():
	var menu_to_spawn = dive_ctrl_menu.instantiate()
	get_parent().add_child(menu_to_spawn)
	queue_free()
