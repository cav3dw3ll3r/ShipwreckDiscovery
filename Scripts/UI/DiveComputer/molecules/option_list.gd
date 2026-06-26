extends DCContentPane
class_name OptionList

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
	if selected_index==0:
		selected_index=len(options)-1
	else:
		selected_index-=1
	select_option(selected_index)

func next():
	selected_index+=1
	selected_index = selected_index%len(options)
	select_option(selected_index)

func accept():
	var option: SingleOptionDisplay = options[selected_index] if len(options) > selected_index else null
	if option == null:
		return
	_navigate_from_option(option)
