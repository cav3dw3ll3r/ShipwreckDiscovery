@tool
extends XRToolsMovementProvider
class_name RapidTapSprint

@export var sprint_action = "ax_button"
@export var burst_curve: Curve # Peak at t=0, decay to 0.0 at t=1
@export var cruise_strength: float = 10.0
@export var burst_strength: float = 25.0
@export var burst_decay_time: float = 0.45
@export var kick_sound_player: AudioStreamPlayer3D

var _burst_time: float = 0.0
var _burst_intensity: float = 0.0
var _was_pressed: bool = false

var camera: XRCamera3D
var playerSM: PlayerStateMachine
var game_settings: GameSettings
var _base_kick_is_left: bool
var order = 50


func _ready() -> void:
	var parent_ctrl := get_parent() as XRController3D
	if parent_ctrl:
		_base_kick_is_left = parent_ctrl.tracker == &"left_hand"
	camera = get_tree().get_first_node_in_group("Player")
	if camera:
		playerSM = camera.get_node_or_null("../PlayerStateMachine") as PlayerStateMachine
	game_settings = get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings and not game_settings.on_settings_update.is_connected(_on_settings_update):
		game_settings.on_settings_update.connect(_on_settings_update)
	if kick_sound_player:
		kick_sound_player.connect("finished", kick_sound_player.stop)


func _exit_tree() -> void:
	if game_settings and game_settings.on_settings_update.is_connected(_on_settings_update):
		game_settings.on_settings_update.disconnect(_on_settings_update)


func _on_settings_update() -> void:
	_burst_time = 0.0
	_burst_intensity = 0.0
	_was_pressed = false
	if kick_sound_player:
		kick_sound_player.stop()


func get_burst_intensity() -> float:
	return _burst_intensity


func _effective_kick_is_left() -> bool:
	if game_settings and not game_settings.switch_hands:
		return not _base_kick_is_left
	return _base_kick_is_left


func _kick_controller() -> XRController3D:
	if _effective_kick_is_left():
		return XRHelpers.get_left_controller(self)
	return XRHelpers.get_right_controller(self)


func _sample_burst_multiplier() -> float:
	if burst_decay_time <= 0.0:
		return 0.0
	var curve_pos := clampf(_burst_time / burst_decay_time, 0.0, 1.0)
	if burst_curve:
		return burst_curve.sample(curve_pos)
	return exp(-_burst_time / burst_decay_time)


func physics_movement(delta: float, player_body: XRToolsPlayerBody, _disabled: bool) -> void:
	var controller := _kick_controller()
	if _disabled or controller == null:
		_burst_intensity = 0.0
		_was_pressed = false
		return

	var is_pressed := controller.is_button_pressed(sprint_action)
	var just_pressed := is_pressed and not _was_pressed
	_was_pressed = is_pressed

	if is_pressed:
		if just_pressed:
			_burst_time = 0.0
			if kick_sound_player and not kick_sound_player.playing:
				kick_sound_player.play()
			controller.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.2, 0.0)

		_burst_time += delta
		_burst_intensity = _sample_burst_multiplier()

		var cam_basis := camera.global_transform.basis
		var direction := -cam_basis.z
		direction.y = clampf(direction.y, -0.4, 0.4)
		direction = direction.normalized()

		var accel := cruise_strength + burst_strength * _burst_intensity
		player_body.velocity += direction * accel * delta
	else:
		if kick_sound_player:
			kick_sound_player.stop()
		_burst_time = 0.0
		_burst_intensity = 0.0
