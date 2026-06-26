extends RichTextLabel

var languageSetting: GameSettings.Language = GameSettings.Language.ENGLISH
var gameSettings:GameSettings
@export_file("*.csv") var stringTablePath: String
@export var stringID: String = ""
@export var bbCode: String = ""

var localization_data = {}

func _ready() -> void:
	get_language_setting()
	load_string_table()
	set_text_value()
	format_text()
	add_to_group("LocalizedElement")

func get_language_setting():
	gameSettings = get_tree().get_first_node_in_group("GameSettings")
	if not gameSettings: return
	gameSettings.on_settings_update.connect(set_text_value)
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
	languageSetting = gameSettings.language
	if stringID.is_empty():
		return
	
	if stringID in localization_data:
		text = localization_data[stringID][languageSetting]  # Get localized text
	else:
		text = stringID+" NOT FOUND"

func format_text():
	if bbCode:
		bbcode_enabled = true
		text = bbCode.format({"TEXT": text})  # Insert text into BBCode template
