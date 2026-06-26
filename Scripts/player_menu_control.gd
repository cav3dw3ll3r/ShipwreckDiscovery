extends Control
class_name PlayerMenu

@onready var glove_button:LocalizedButton = $HBoxContainer/LocalizedButton
@onready var powers_button:LocalizedButton = $HBoxContainer/LocalizedButton2
@onready var sandbox_button:LocalizedButton = $HBoxContainer/LocalizedButton3
@onready var equip_sound_player = $AudioStreamPlayer3D
@onready var items_list = $ScrollContainer/MarginContainer/VBoxContainer

var item_prefab = preload("res://Prefabs/UI/glove_panel.tscn")
var power_prefab = preload("res://Prefabs/UI/powers_panel.tscn")
var sandbox_prefab = preload("res://Prefabs/UI/sandbox_panel.tscn")
var player_coins:int
var shop_item_prefab = preload("res://Prefabs/UI/shop_item_panel.tscn")
func _ready() -> void:
	initialize_sandbox_items()
	glove_button.pressed.connect(initialize_glove_items)
	powers_button.pressed.connect(initialize_power_items)
	sandbox_button.pressed.connect(initialize_sandbox_items)
	

func on_equip_glove():
	equip_sound_player.play()
	initialize_glove_items()

func initialize_power_items():
	for node in items_list.get_children():
		node.queue_free()

func initialize_glove_items():
	for node in items_list.get_children():
		node.queue_free()

func initialize_sandbox_items():
	for node in items_list.get_children():
		node.queue_free()
