extends DisplayPane
class_name ScanDetailsPane

var scannable: Scannable
var hologram: Node3D

var startup_time := 0.0
var audio_started := false

func _ready() -> void:
	super._ready()
	if not scannable:
		accept()
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
		if game_settings != null and game_settings.mute_videos:
			return
		$VoicePlayer.finished.connect(accept)
		$VoicePlayer.stream = scannable.scan_audio
		$VoicePlayer.play()


func accept() -> void:
	if hologram:
		hologram.queue_free()
		hologram = null

	var option: SingleOptionDisplay = options[selected_index] if len(options) > selected_index else null
	if option == null:
		return

	_navigate_from_option(option)
