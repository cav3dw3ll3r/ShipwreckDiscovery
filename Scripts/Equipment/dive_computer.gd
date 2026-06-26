extends Node3D
class_name WorldDiveComputer

@export var prev_button: PhysicalPressButton
@export var ok_button: PhysicalPressButton
@export var next_button: PhysicalPressButton
@export var fingertip: Node3D

@export_group("Button Feedback")
@export var button_haptic_amplitude: float = 0.15
@export var button_haptic_duration: float = 0.08

@onready var menu_node = $ComputerMenu/SubViewport/DCMenu
@onready var _navigate_sound: AudioStreamPlayer3D = $NavigateSound
@onready var _accept_sound: AudioStreamPlayer3D = $AcceptSound

var _right_controller: XRController3D
var _fingertip: Node3D
var _interaction_active: bool = false
var _primed_button: PhysicalPressButton
var _was_trigger_click: bool = false
var _player_state_machine: PlayerStateMachine


func _ready() -> void:
	prev_button.pressed.connect(_on_prev_pressed)
	ok_button.pressed.connect(_on_accept_pressed)
	next_button.pressed.connect(_on_next_pressed)
	_cache_fingertip()
	_cache_right_controller()
	_set_interaction_active(false)
	_disable_after_initial_render()


func _process(_delta: float) -> void:
	if _fingertip == null:
		_cache_fingertip()
	if _right_controller == null:
		_cache_right_controller()

	var overlapping := _buttons_with_finger_overlap()
	if overlapping.is_empty():
		_set_interaction_active(false)
		_set_primed_button(null)
		_was_trigger_click = false
		return

	_set_interaction_active(true)
	_set_primed_button(_closest_button(overlapping))
	_handle_trigger_press()


func _cache_fingertip() -> void:
	if fingertip != null:
		_fingertip = fingertip
		return
	var nodes := get_tree().get_nodes_in_group("dive_computer_fingertip")
	if not nodes.is_empty():
		_fingertip = nodes[0] as Node3D


func _cache_right_controller() -> void:
	_right_controller = XRHelpers.get_right_controller(self)


func _buttons() -> Array[PhysicalPressButton]:
	var buttons: Array[PhysicalPressButton] = []
	if prev_button != null:
		buttons.append(prev_button)
	if ok_button != null:
		buttons.append(ok_button)
	if next_button != null:
		buttons.append(next_button)
	return buttons


func _buttons_with_finger_overlap() -> Array[PhysicalPressButton]:
	var overlapping: Array[PhysicalPressButton] = []
	for button in _buttons():
		if button.has_finger_overlap():
			overlapping.append(button)
	return overlapping


func _closest_button(candidates: Array[PhysicalPressButton]) -> PhysicalPressButton:
	var finger_pos := _fingertip.global_position if _fingertip != null else candidates[0].global_position
	var closest: PhysicalPressButton = candidates[0]
	var best_dist_sq := finger_pos.distance_squared_to(closest.global_position)
	for i in range(1, candidates.size()):
		var candidate := candidates[i]
		var dist_sq := finger_pos.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			closest = candidate
	return closest


func _handle_trigger_press() -> void:
	if _right_controller == null or not _right_controller.get_is_active():
		_was_trigger_click = false
		return

	var trigger_click := _right_controller.is_button_pressed("trigger_click")
	if trigger_click and not _was_trigger_click and _primed_button != null:
		_primed_button.activate()
	_was_trigger_click = trigger_click


func _set_primed_button(button: PhysicalPressButton) -> void:
	if _primed_button == button:
		return
	for candidate in _buttons():
		candidate.set_primed(candidate == button)
	_primed_button = button


func _set_interaction_active(is_active: bool) -> void:
	if _interaction_active == is_active:
		return
	_interaction_active = is_active

	for button in _buttons():
		button.set_interaction_active(is_active)

	var viewport := get_node_or_null("ComputerMenu/SubViewport") as SubViewport
	if viewport != null:
		viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED
		)

	get_tree().call_group("right_hand", "force_point", is_active)


func _cache_player_state_machine() -> void:
	if _player_state_machine != null and is_instance_valid(_player_state_machine):
		return
	var player_node := get_tree().get_first_node_in_group("Player")
	if player_node == null:
		return
	_player_state_machine = player_node.get_parent().get_node_or_null("PlayerStateMachine") as PlayerStateMachine


func _trigger_dual_haptics() -> void:
	_cache_player_state_machine()
	if _player_state_machine != null:
		_player_state_machine.dual_haptic_pulse(button_haptic_amplitude, button_haptic_duration)


func _play_button_feedback(is_accept: bool) -> void:
	_trigger_dual_haptics()
	if is_accept:
		_accept_sound.play()
	else:
		_navigate_sound.play()


func _on_prev_pressed() -> void:
	_play_button_feedback(false)
	menu_node.on_prev()


func _on_accept_pressed() -> void:
	_play_button_feedback(true)
	menu_node.on_accept()


func _on_next_pressed() -> void:
	_play_button_feedback(false)
	menu_node.on_next()


func _disable_after_initial_render() -> void:
	await get_tree().process_frame
	_set_interaction_active(false)
