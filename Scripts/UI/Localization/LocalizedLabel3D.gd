extends Label3D
class_name LocalizedLabel3D

var languageSetting: GameSettings.Language = GameSettings.Language.ENGLISH
var gameSettings: GameSettings
@export_file("*.tsv") var stringTablePath: String
@export var stringID: String = ""

var localization_data = {}

func _ready() -> void:
	get_language_setting()
	update()
	add_to_group("LocalizedElement")

func update() -> void:
	if localization_data.is_empty():
		load_string_table()
	set_text_value()

func refresh() -> void:
	get_language_setting()
	load_string_table()
	set_text_value()

func get_language_setting() -> void:
	gameSettings = get_tree().get_first_node_in_group("GameSettings")
	if not gameSettings:
		return
	languageSetting = gameSettings.language

func load_string_table() -> void:
	if stringTablePath.is_empty():
		return

	var file := FileAccess.open(stringTablePath, FileAccess.READ)
	if not file:
		return

	var is_first_line := true
	while not file.eof_reached():
		var line := file.get_line()
		if is_first_line:
			is_first_line = false
			continue

		var values := line.split("\t")
		if values.size() >= 6:
			var key := values[0].strip_edges()
			localization_data[key] = values.slice(1, 6)
	file.close()

func set_text_value() -> void:
	if gameSettings:
		languageSetting = gameSettings.language
	else:
		languageSetting = GameSettings.Language.ENGLISH

	if stringID.is_empty():
		return

	if stringID in localization_data:
		var row: Array = localization_data[stringID]
		if languageSetting >= 0 and languageSetting < row.size():
			text = row[languageSetting]
		else:
			text = stringID + " NOT FOUND"
	else:
		text = stringID + " NOT FOUND"
