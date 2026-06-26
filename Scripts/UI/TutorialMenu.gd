extends MarginContainer

@export var slide_title_Ids:Array[String]

@onready var _slides_container: MarginContainer = $VBoxContainer/VBoxContainer/MarginContainer
@onready var _title: LocalizedLabel = $VBoxContainer/VBoxContainer/Title
@onready var _prev: Button = $VBoxContainer/HBoxContainer/Prev
@onready var _next: Button = $VBoxContainer/HBoxContainer/Next
@onready var _current: Label = $VBoxContainer/HBoxContainer/Current

var _slides: Array = []
var _selected_index: int = 0


func _ready() -> void:
	for child in _slides_container.get_children():
		if child:
			_slides.append(child)
	_prev.pressed.connect(_on_prev)
	_next.pressed.connect(_on_next)
	_show_slide(0)


func _show_slide(index: int) -> void:
	_selected_index = index
	for i in range(_slides.size()):
		_slides[i].visible = i == index
	_current.text = "%d/%d" % [index + 1, _slides.size()]
	if index >= 0 and index < slide_title_Ids.size():
		_title.stringID = slide_title_Ids[index]
		_title.update()


func _on_prev() -> void:
	var idx := _selected_index - 1
	if idx < 0:
		idx = _slides.size() - 1
	_show_slide(idx)


func _on_next() -> void:
	_show_slide((_selected_index + 1) % _slides.size())
