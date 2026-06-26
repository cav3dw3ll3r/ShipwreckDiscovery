extends HBoxContainer
class_name SingleOptionDisplay

@export var selected_line:StyleBoxLine
@export var option_link:PackedScene
## When true, accept navigates back to the pane that opened this one via the menu stack.
@export var return_to_previous: bool = false
@export var option_action:Node

@onready var separator:VSeparator=$VSeparator
@onready var selector_icon:TextureRect=$Selector
@onready var label=$Label

func _ready() -> void:
	set_active(false)

func set_active(is_active:bool):
	selector_icon.visible=is_active
	if(is_active):
		add_theme_constant_override("separation",20)
		separator.add_theme_stylebox_override("separator",selected_line)
	else:
		remove_theme_constant_override("separation")
		separator.remove_theme_stylebox_override("separator")

func run_option_action() -> void:
	if option_action is SimpleAction:
		(option_action as SimpleAction).do()
