extends Label
class_name VideoSubtitles

@export var subtitle_table_path := "res://Resources/StringTables/Video_Subtitles.tsv"

var localization_data := {}
var game_settings
var current_clip_key := ""

func _ready() -> void:
	game_settings = get_tree().get_first_node_in_group("GameSettings")
	load_string_table()

func load_string_table() -> void:
	if subtitle_table_path.is_empty():
		push_warning("No subtitle table path provided.")
		return
	
	var file := FileAccess.open(subtitle_table_path, FileAccess.READ)
	if not file:
		push_error("Failed to open subtitle table: %s" % subtitle_table_path)
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

func set_clip_key(clip_key: String) -> void:
	current_clip_key = clip_key
	update_text()

func update_text() -> void:
	if not game_settings:
		text = ""
		return
	
	var language = game_settings.language
	
	if current_clip_key in localization_data:
		text = localization_data[current_clip_key][language]
	else:
		text = "%s NOT FOUND" % current_clip_key
		push_warning("Subtitle key not found: %s" % current_clip_key)
