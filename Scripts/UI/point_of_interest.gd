## DEPRECATED: Not used in Optimized_Base / going forward; kept for reference.
extends Control

@onready var boundScene = preload("res://Prefabs/UI/credits_menu.tscn")

var popup_controller:FrontMenu

func _ready() -> void:
	popup_controller = get_tree().get_first_node_in_group("PopupMenu")

func open_popup_menu():
	popup_controller.displayMenu(boundScene)
