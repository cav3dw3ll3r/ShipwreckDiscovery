extends MeshInstance3D
class_name ComicPanel

signal switched_on
signal switched_off

@export var on_duration: float = 0.4
@export var off_duration: float = 0.4
@export var text_pop_duration: float = 0.1
@export var panel_audio: AudioStream
@export var panel_texture: Texture2D
@export var skip_button_action: StringName = &"ax_button"
@export_file("*.tsv") var stringTablePath: String = "res://Resources/StringTables/IntroPanelStrings.tsv"
@export var stringID: String = ""

@onready var _label: LocalizedLabel3D = $LocalizedLabel
@onready var _audio_player: AudioStreamPlayer3D = $PanelAudio

var _material: ShaderMaterial
var _label_base_scale: Vector3 = Vector3.ONE
var _active_tween: Tween
var _skip_was_down: bool = false
var _advance_done: bool = false


func _enter_tree() -> void:
	var label = get_node_or_null("LocalizedLabel") as LocalizedLabel3D
	if label == null:
		return
	if not stringTablePath.is_empty():
		label.stringTablePath = stringTablePath
	if not stringID.is_empty():
		label.stringID = stringID


func _ready() -> void:
	await get_tree().process_frame
	_ensure_material()
	_setup_caption()
	visible = false


func _ensure_material() -> void:
	if _material != null:
		return
	_setup_material()


func _setup_material() -> void:
	var source := get_surface_override_material(0) as ShaderMaterial
	if source == null:
		source = get_active_material(0) as ShaderMaterial
	if source == null:
		push_warning("ComicPanel: no shader material found on %s" % name)
		return
	_material = source.duplicate() as ShaderMaterial
	set_surface_override_material(0, _material)
	_material.set_shader_parameter("progress", 0.0)
	_apply_panel_texture()


func _setup_caption() -> void:
	if _label == null:
		return
	_label_base_scale = _label.scale
	_hide_caption()


func _apply_panel_texture() -> void:
	if _material and panel_texture:
		_material.set_shader_parameter("texture_albedo", panel_texture)


func switch_on() -> void:
	_kill_tweens()
	_ensure_material()
	_apply_panel_texture()
	visible = true

	if _material:
		_material.set_shader_parameter("progress", 0.0)
	_hide_caption()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

	if _material:
		tween.tween_method(_apply_progress, 0.0, 1.0, on_duration)

	if _label:
		_label.visible = true
		_label.scale = Vector3.ZERO
		tween.tween_property(_label, "scale", _label_base_scale, text_pop_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _audio_player and panel_audio:
		_audio_player.stream = panel_audio
		_audio_player.play()

	_active_tween = tween
	await tween.finished
	_active_tween = null

	await _wait_for_advance()

	if _audio_player:
		_audio_player.stop()

	await switch_off()
	switched_on.emit()


func switch_off() -> void:
	_kill_tweens()
	_hide_caption()

	if _material == null:
		visible = false
		switched_off.emit()
		return

	var from_progress: float = _material.get_shader_parameter("progress")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_progress, from_progress, 0.0, off_duration)

	_active_tween = tween
	await tween.finished
	_active_tween = null
	visible = false
	switched_off.emit()


func _wait_for_advance() -> void:
	_advance_done = false
	var audio_configured = _audio_player != null and panel_audio != null
	var audio_was_playing = false

	if audio_configured and not _audio_player.playing:
		_audio_player.stream = panel_audio
		_audio_player.play()

	if audio_configured:
		_audio_player.finished.connect(func() -> void:
			_advance_done = true
		, CONNECT_ONE_SHOT)

	_skip_was_down = _is_skip_down()
	while not _advance_done:
		if _is_skip_just_pressed():
			break
		if audio_configured:
			if _audio_player.playing:
				audio_was_playing = true
			elif audio_was_playing:
				_advance_done = true
		await get_tree().process_frame


func _is_skip_down() -> bool:
	var left := XRHelpers.get_left_controller(self)
	var right := XRHelpers.get_right_controller(self)
	return (left and left.is_button_pressed(skip_button_action)) \
		or (right and right.is_button_pressed(skip_button_action))


func _is_skip_just_pressed() -> bool:
	var down := _is_skip_down()
	var just_pressed := down and not _skip_was_down
	_skip_was_down = down
	return just_pressed


func _hide_caption() -> void:
	if _label:
		_label.visible = false
		_label.scale = Vector3.ZERO


func _kill_tweens() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _apply_progress(value: float) -> void:
	if _material:
		_material.set_shader_parameter("progress", clampf(value, 0.0, 1.0))
