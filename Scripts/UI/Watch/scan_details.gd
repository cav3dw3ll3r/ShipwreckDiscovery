extends Control
class_name Scan_Details

var scanner_menu: PackedScene = preload("res://Prefabs/UI/WatchSubMenus/scanner_menu.tscn")
var scannable: Scannable
var hologram: Node3D

@export var return_pane: PackedScene
@export var use_menu_controller: bool = false

var startup_time = 0.0
var audio_started = false


func _ready() -> void:
	if not scannable:
		back()
		return
	$Ping.play()


func _process(delta: float) -> void:
	startup_time += delta
	startup_time = min(startup_time, 0.25)
	if hologram != null and hologram.has_method("set_anim_progress"):
		hologram.set_anim_progress(startup_time * 4)
	if startup_time >= 0.25 and not audio_started:
		audio_started = true
		var game_settings: GameSettings = get_tree().get_first_node_in_group("GameSettings")
		if game_settings.mute_videos:
			return
		$VoicePlayer.finished.connect(back)
		$VoicePlayer.stream = scannable.scan_audio
		$VoicePlayer.play()


func back() -> void:
	if use_menu_controller:
		var return_scene := return_pane if return_pane != null else scanner_menu
		var menu := _find_menu_controller()
		if menu != null:
			menu.set_main_content_pane(return_scene.instantiate())
		if hologram:
			hologram.queue_free()
		queue_free()
		return

	var menu_inst = scanner_menu.instantiate()
	get_parent().add_child(menu_inst)
	if hologram:
		hologram.queue_free()
	queue_free()


func _find_menu_controller() -> MarginContainer:
	var node: Node = self
	while node != null:
		if node.has_method("set_main_content_pane") and node.get("base_content_pane") != null:
			return node as MarginContainer
		node = node.get_parent()
	return null
