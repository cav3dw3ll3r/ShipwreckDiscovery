class_name TriggerClickDetector
extends RefCounted

## Counts discrete [code]trigger_click[/code] presses within a short window.

signal pattern_completed(click_count: int)

var max_clicks: int = 4
var pattern_quiet_seconds: float = 0.48

var _click_count: int = 0
var _time_since_last_click: float = 0.0
var _was_trigger_click: bool = false
var _armed: bool = true


func reset() -> void:
	_click_count = 0
	_time_since_last_click = 0.0
	_was_trigger_click = false
	_armed = true


func poll(controller: XRController3D, delta: float) -> void:
	if controller == null or not controller.get_is_active():
		_flush_if_needed(true)
		_was_trigger_click = false
		return

	var trigger_click := controller.is_button_pressed("trigger_click")
	if trigger_click and not _was_trigger_click and _armed:
		_register_click()
	_was_trigger_click = trigger_click

	if _click_count > 0:
		_time_since_last_click += delta
		if _time_since_last_click >= pattern_quiet_seconds:
			_emit_and_reset()


func _register_click() -> void:
	_click_count = mini(_click_count + 1, max_clicks)
	_time_since_last_click = 0.0


func _emit_and_reset() -> void:
	if _click_count <= 0:
		return
	var count := _click_count
	_click_count = 0
	_time_since_last_click = 0.0
	pattern_completed.emit(count)


func _flush_if_needed(force: bool) -> void:
	if _click_count <= 0:
		return
	if force or _time_since_last_click >= pattern_quiet_seconds:
		_emit_and_reset()
