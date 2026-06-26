extends Button

class_name LocalizedButton

var languageSetting: GameSettings.Language = GameSettings.Language.ENGLISH
var gameSettings:GameSettings
@export_file("*.tsv") var stringTablePath: String
@export var stringID: String = ""
@export var quick_trigger_group_name=""

var localization_data = {}

func _ready() -> void:
	get_language_setting()
	load_string_table()
	set_text_value()
	add_to_group("LocalizedElement")
	connect("pressed",on_press)

func on_press():
	for node in get_tree().get_nodes_in_group(quick_trigger_group_name):
		if node.has_method("trigger"):
			node.trigger()

func refresh():
	get_language_setting()
	load_string_table()
	set_text_value()

func get_language_setting():
	gameSettings = get_tree().get_first_node_in_group("GameSettings")
	if not gameSettings: return
	languageSetting = gameSettings.language

func load_string_table():
	if stringTablePath.is_empty():
		return
	
	var file = FileAccess.open(stringTablePath, FileAccess.READ)
	if file:
		var is_first_line = true
		while not file.eof_reached():
			var line = file.get_line()
			if is_first_line:
				is_first_line = false  # Skip the first line (header row)
				continue
			
			var values = line.split("\t")
			if values.size() >= 6:  # Ensure we have all expected columns
				var key = values[0].strip_edges()
				localization_data[key] = values.slice(1, 6)  # Store language values
		file.close()
	else:
		pass

func set_text_value():
	if not gameSettings: 
		return
	languageSetting = gameSettings.language
	if stringID.is_empty():
		return
	
	if stringID in localization_data:
		text = localization_data[stringID][languageSetting]  # Get localized text
	else:
		text = stringID+" NOT FOUND"
