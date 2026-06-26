extends Control
class_name DCContentPane

signal change_pane(pane:DCContentPane)

func next():
	pass

func accept():
	pass

func prev():
	pass

func _find_menu_controller() -> MarginContainer:
	var node: Node = self
	while node != null:
		if node.has_method("set_main_content_pane") and node.get("base_content_pane") != null:
			return node as MarginContainer
		node = node.get_parent()
	return null

func _navigate_from_option(option: SingleOptionDisplay) -> void:
	option.run_option_action()
	if option.option_link != null:
		change_pane.emit(option.option_link.instantiate() as DCContentPane)
	elif option.return_to_previous:
		var menu := _find_menu_controller()
		if menu != null:
			menu.navigate_to_previous()
