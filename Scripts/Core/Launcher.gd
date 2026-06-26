extends Node3D
class_name Launcher

const INTRO_SCENE := "res://Scenes/Intro.tscn"

var scene_base: XRToolsSceneBase
var current_level

var time_waited = 0.0
var popped = false

func _ready() -> void:
	call_deferred("_init_launcher")

func _init_launcher() -> void:
	await get_tree().process_frame
	Launch_Game()
	_restore_skip_toggle()

func Launch_Game():
	current_level = load($"../GameSettings".current_level).scene_path
	scene_base= XRTools.find_xr_ancestor(self, "*", "XRToolsSceneBase")

func _process(delta: float) -> void:
	time_waited+=delta

func trigger():
	if time_waited > 2.0 and not popped:
		_persist_skip_preference()
		popped = true
		var game_settings := $"../GameSettings" as GameSettings
		if game_settings and game_settings.skip_cinematic_intro:
			launch()
		else:
			scene_base.load_scene(INTRO_SCENE, null)

func launch():
	var game_settings := $"../GameSettings" as GameSettings
	if game_settings:
		game_settings.pending_auto_instant_dive = false
	scene_base.load_scene(current_level, "Respawn")

func _get_skip_checkbox() -> CheckBox:
	for node in get_tree().get_nodes_in_group("SkipIntroToggle"):
		return node as CheckBox
	return null

func _restore_skip_toggle() -> void:
	var checkbox := _get_skip_checkbox()
	var game_settings := $"../GameSettings" as GameSettings
	if checkbox and game_settings:
		checkbox.set_pressed_no_signal(game_settings.skip_cinematic_intro)

func _persist_skip_preference() -> void:
	var checkbox := _get_skip_checkbox()
	var game_settings := $"../GameSettings" as GameSettings
	if checkbox and game_settings:
		game_settings.skip_cinematic_intro = checkbox.button_pressed
		SaveLoad.save_all()
