extends MarginContainer

const STRING_TABLE_PATH := "res://Resources/StringTables/DiveSummaryStrings.tsv"

const SUMMARY_ROWS := [
	{
		"label_id": "DiveSummary_Duration",
		"report_key": "duration_seconds",
		"value_type": "duration",
	},
	{
		"label_id": "DiveSummary_LionfishCulled",
		"report_key": "lionfish_delta",
		"value_type": "int",
	},
	{
		"label_id": "DiveSummary_TrashRemoved",
		"report_key": "trash_delta",
		"value_type": "int",
	},
	{
		"label_id": "DiveSummary_CoralsPlanted",
		"report_key": "planted",
		"value_type": "array_count",
	},
	{
		"label_id": "DiveSummary_CoralsDestroyed",
		"report_key": "destroyed",
		"value_type": "array_count",
	},
]

@onready var _summary_rows: VBoxContainer = $VBoxContainer/SummaryRows

var _wreck_id: String = ""
var _dive_report: Dictionary = {}
var _is_ready := false


func _ready() -> void:
	_is_ready = true
	_rebuild_summary()


func setup(wreck_id: String, dive_report: Dictionary) -> void:
	_wreck_id = wreck_id
	_dive_report = dive_report
	if _is_ready:
		_rebuild_summary()


func _rebuild_summary() -> void:
	if _summary_rows == null:
		return

	for child in _summary_rows.get_children():
		_summary_rows.remove_child(child)
		child.queue_free()

	for row_data in SUMMARY_ROWS:
		_summary_rows.add_child(_create_summary_row(row_data))


func _create_summary_row(row_data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)

	var label := LocalizedLabel.new()
	label.stringTablePath = STRING_TABLE_PATH
	label.stringID = row_data["label_id"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = row_data["label_id"]
	row.add_child(label)

	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _get_report_value_text(row_data)
	row.add_child(value_label)

	return row


func _get_report_value_text(row_data: Dictionary) -> String:
	var value = _dive_report.get(row_data["report_key"], null)

	match row_data["value_type"]:
		"duration":
			return _format_duration_seconds(value)
		"array_count":
			if value is Array:
				return str(value.size())
			return "0"
		_:
			return str(int(value)) if value != null else "0"


func _format_duration_seconds(value) -> String:
	var total_seconds := maxi(0, int(round(float(value) if value != null else 0.0)))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
