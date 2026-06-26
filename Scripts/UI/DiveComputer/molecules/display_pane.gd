extends DCContentPane
class_name DisplayPane

var options:Array
var selected_index = 0

func _ready() -> void:
	options = []
	for child in get_children():
		if child is SingleOptionDisplay:
			options.append(child)
	select_option(selected_index)

func select_option(index:int):
	for i in range(len(options)):
		if i == index:
			options[i].set_active(true)
		else:
			options[i].set_active(false)

func prev():
	pass

func next():
	pass

func accept():
	var option: SingleOptionDisplay = options[selected_index] if len(options) > selected_index else null
	if option == null:
		return
	_navigate_from_option(option)
