## DEPRECATED: Not used in Optimized_Base / going forward; kept for reference.
extends Node

var popup_controller:FrontMenu

func _ready() -> void:
	popup_controller = get_tree().get_first_node_in_group("PopupMenu")
	$MenuPanel/HBoxContainer/ButtonHolder/CloseButton.pressed.connect(close)

func close():
	popup_controller.closeMenu()
