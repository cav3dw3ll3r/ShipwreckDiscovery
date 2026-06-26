extends MeshInstance3D

class_name ResourceTextDisplay

var languageSetting: GameSettings.Language = GameSettings.Language.ENGLISH
var gameSettings:GameSettings
var stringTablePath: String
@export_file var resource_property_name: String
var stringID: String = ""


var localization_data = {}

var stringTableLoaded = false

var text_mesh:TextMesh

func _ready() -> void:
	if(mesh is TextMesh):
		text_mesh = mesh
	get_language_setting()
	call_deferred("initialize")
	add_to_group("LocalizedElement")

func initialize():
	var game_settings:GameSettings = get_tree().get_first_node_in_group("GameSettings")
	if not game_settings: return
	var level_resrouce:LevelData = load(game_settings.current_level)
	setup(level_resrouce,resource_property_name,level_resrouce.stringTable)

func setup(resource: Resource, property_name: String, string_table_path: String) -> void:
	if resource == null:
		push_error("ResourceTextDisplay.setup(): Resource is null.")
		return
	if property_name.is_empty():
		push_error("ResourceTextDisplay.setup(): Property name is empty.")
		return

	self.stringTablePath = string_table_path

	# Try to extract the stringID from the resource property
	if resource.has_method("get"):  # works for most Godot resources
		stringID = str(resource.get(property_name))
	else:
		push_error("ResourceTextDisplay.setup(): Resource does not support property access.")

	# Update text based on the new values
	update()

func update():
	if(localization_data.is_empty()):
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
	if(gameSettings):
		languageSetting = gameSettings.language
	else:
		languageSetting=GameSettings.Language.ENGLISH
		
	if stringID.is_empty():
		return
	
	if stringID in localization_data:
		text_mesh.text = localization_data[stringID][languageSetting]  # Get localized text
	else:
		text_mesh.text = stringID+" NOT FOUND"
