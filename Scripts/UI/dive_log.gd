extends Control

@onready var stats_btn = $ProducedBy/Container/MarginContainer/VBoxContainer/StatsButton
@onready var wrecks_btn = $ProducedBy/Container/MarginContainer/VBoxContainer/WrecksButton
@onready var creatures_btn = $ProducedBy/Container/MarginContainer/VBoxContainer/CreaturesButton
@onready var context_menu = $ProducedBy/ScrollContainer

@onready var stats_menu = preload("res://Prefabs/UI/stats_window.tscn")
@onready var wreck_data_menu = preload("res://Prefabs/UI/wreck_data_menu.tscn")
@onready var creature_menu = preload("res://Prefabs/UI/creature_data_menu.tscn")

@onready var menus = [stats_menu,
				wreck_data_menu,
				creature_menu]

func _ready():
	stats_btn.pressed.connect(func(): show_menu(0))
	wrecks_btn.pressed.connect(func(): show_menu(1))
	creatures_btn.pressed.connect(func(): show_menu(2))

func show_menu(menuIndex):
	for child in context_menu.get_children():
		child.queue_free()
	context_menu.add_child(menus[menuIndex].instantiate())
