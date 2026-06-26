extends PanelContainer
class_name TravelWreckPanel

signal travel_pressed
signal instant_dive_pressed

const WRECK_STATUS_STRING_TABLE := "res://Resources/StringTables/WreckStatusStrings.tsv"

@onready var _name_label: LocalizedLabel = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/Name
@onready var _status_label: LocalizedLabel = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/Name2
@onready var _here_indicator: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/Here
@onready var _travel_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Actions/TravelButton
@onready var _instant_dive_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Actions/InstantDiveButton
@onready var _lionfish_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/Label
@onready var _trash_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ProgressBar
@onready var _baby_coral_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/Label2
@onready var _growing_coral_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/Label3
@onready var _pristine_coral_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/Label4

var level_data: LevelData
var is_current_wreck: bool = false

func setup(level: LevelData, is_current_wreck: bool) -> void:
	level_data = level
	self.is_current_wreck = is_current_wreck
	_name_label.stringID = level.nameID
	_name_label.stringTablePath = level.stringTable
	_name_label.update()

	refresh_display()

func refresh_display() -> void:
	if level_data == null:
		return

	var display := SessionManager.get_wreck_display_data(level_data.nameID, level_data)
	var status_string_id: String = display.get("status_string_id", "WreckStatus_SterilePlantCoral")
	_status_label.stringTablePath = WRECK_STATUS_STRING_TABLE
	_status_label.stringID = status_string_id
	_status_label.update()
	_status_label.add_theme_color_override(
		"font_color",
		WreckStatusEvaluator.get_severity_color(display.get("status_severity", WreckStatusEvaluator.StatusSeverity.CAUTION))
	)

	_lionfish_label.text = str(display.get("lionfish", 0))
	_trash_bar.value = display.get("trash", 0.0) * 100.0

	var tier_counts: Array = display.get("coral_tier_counts", [0, 0, 0])
	_baby_coral_label.text = str(tier_counts[0])
	_growing_coral_label.text = str(tier_counts[1])
	_pristine_coral_label.text = str(tier_counts[2])

	_here_indicator.visible = is_current_wreck
	_travel_button.visible = not is_current_wreck
	_instant_dive_button.visible = is_current_wreck

func _on_travel_button_pressed() -> void:
	travel_pressed.emit()

func _on_instant_dive_button_pressed() -> void:
	instant_dive_pressed.emit()
