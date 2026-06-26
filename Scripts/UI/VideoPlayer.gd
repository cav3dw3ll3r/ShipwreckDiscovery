extends Control

class_name VideoPlayer

@export var clips:Array[VideoStream]
@export var player:VideoStreamPlayer

@onready var seek_buttons_container = $VBoxContainer/VBoxContainer

@onready var game_settings = get_tree().get_first_node_in_group("GameSettings")

var seek_buttons:Array[TextureButton]
var off_texture = preload("res://Resources/Stylesheets/UI_Components/IconButton/IconButton10Cyan_n.png")
var on_texture = preload("res://Resources/Stylesheets/UI_Components/IconButton/IconButton09Cyan_p.png")
var hover_texture = preload("res://Resources/Stylesheets/UI_Components/IconButton/IconButton10Cyan_p.png")
var currentPos:int = 0
var localization_data = {}
var clip_file_names:Array[String] = []
var languageSetting
const subtitle_table_path = "res://Resources/StringTables/Video_Subtitles.tsv"

func on_close():
	player.stop()

func _process(delta: float) -> void:
	$HBoxContainer/AspectRatioContainer/TextureRect.texture = player.get_video_texture()

func seek(index):
	if(len(seek_buttons)<=index): return
	for button in seek_buttons:
		button.texture_normal = off_texture
		button.texture_hover = hover_texture
	seek_buttons[index].texture_normal = on_texture
	seek_buttons[index].texture_hover = null
	currentPos = index
	player.stream=clips[currentPos]
	apply_mute()
	set_text_value()
	player.play()

func toggle_mute(new_val):
	game_settings.mute_videos = new_val
	apply_mute()

func apply_mute():
	if game_settings.mute_videos:
		player.volume = 0
	else:
		player.volume = 1
		player.volume_db = game_settings.voice_volume

func next():
	if(currentPos<len(clips)-1):
		seek(currentPos+1)
	else:
		var popup_control = get_tree().get_first_node_in_group("PopupMenu")
		if popup_control:
			popup_control.closeMenu()

func prev():
	if(currentPos>0):
		seek(currentPos-1)

func toggle_pause():
	player.paused = not player.paused

func load_string_table():
	if subtitle_table_path.is_empty():
		return
	
	var file = FileAccess.open(subtitle_table_path, FileAccess.READ)
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

func get_language_setting():
	game_settings = get_tree().get_first_node_in_group("GameSettings")
	if not game_settings: return
	languageSetting = game_settings.language

func set_text_value():
	if(game_settings):
		languageSetting = game_settings.language
	else:
		languageSetting=GameSettings.Language.ENGLISH
		
	
	if clip_file_names[currentPos] in localization_data:
		$HBoxContainer/Subtitles.text = localization_data[clip_file_names[currentPos]][game_settings.language]  # Get localized text
	else:
		$HBoxContainer/Subtitles.text = clip_file_names[currentPos]+" NOT FOUND"

func _ready() -> void:
	get_language_setting()
	load_string_table()
	$VBoxContainer/CheckBox.set_pressed_no_signal(game_settings.mute_videos)
	for i in range(len(clips)):
		seek_buttons.append(TextureButton.new())
		seek_buttons[i].texture_normal = off_texture
		seek_buttons[i].texture_hover = hover_texture
		seek_buttons[i].ignore_texture_size = true
		seek_buttons[i].stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		seek_buttons[i].custom_minimum_size=Vector2(50,50)
		var seek_index = i
		seek_buttons[i].pressed.connect(func():seek(seek_index))
		seek_buttons_container.add_child(seek_buttons[i])
	seek(0)
