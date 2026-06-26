extends Node3D

signal hoop_passed(hoop: Node)

## Local direction that counts as a successful swim-through (hoop root forward is -Z).
@export var pass_local_direction: Vector3 = Vector3.FORWARD
@export var direction_dot_threshold: float = 0.35
@export var min_speed: float = 0.25
@export var fail_cooldown_sec: float = 1.5
## Peak push strength along the hoop forward axis (applied over several frames).
@export var pass_boost_speed: float = 10.0
## Lower values make the boost fade out more slowly (per-second decay rate).
@export var pass_boost_decay: float = 0.65
## Seconds to ramp shader progress up when the hoop starts moving along the path.
@export var travel_glow_ramp: float = 0.35
## Seconds to ease back to idle when the hoop stops at the next checkpoint.
@export var arrival_glow_ramp: float = 0.25

@onready var area: Area3D = $Area3D
@onready var mesh: MeshInstance3D = $Torus
@onready var pass_audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var fail_audio: AudioStreamPlayer3D = $FailSound

var _passed := false
var _cooldown_until_msec := 0
var _ring_material: ShaderMaterial
var _visual_tween: Tween
var _vanish_tween: Tween


func _ready() -> void:
	_ensure_ring_material()
	area.collision_mask = 32
	area.monitoring = true
	area.body_entered.connect(_on_body_entered)
	set_waiting()


func _ensure_ring_material() -> void:
	if _ring_material or mesh == null:
		return
	var source := mesh.get_surface_override_material(0) as ShaderMaterial
	if source == null:
		source = mesh.get_active_material(0) as ShaderMaterial
	if source == null:
		return
	_ring_material = source.duplicate() as ShaderMaterial
	mesh.set_surface_override_material(0, _ring_material)


func _set_shader_param(param: StringName, value: float) -> void:
	_ensure_ring_material()
	if _ring_material:
		_ring_material.set_shader_parameter(param, value)
	elif mesh:
		mesh.set_instance_shader_parameter(param, value)


func _set_progress(value: float) -> void:
	_set_shader_param(&"progress", value)


func _set_vanish(value: float) -> void:
	_set_shader_param(&"vanish_amount", value)


func set_waiting() -> void:
	_kill_tweens()
	_passed = false
	area.monitoring = true
	_set_vanish(0.0)
	_ramp_progress(0.0, arrival_glow_ramp)


func set_travelling() -> void:
	_kill_tweens()
	_passed = true
	area.monitoring = false
	_set_vanish(0.0)
	_ramp_progress(1.0, travel_glow_ramp)


func play_vanish(duration: float, on_finished: Callable = Callable()) -> void:
	_kill_tweens()
	_passed = true
	area.monitoring = false
	var vanish_time := maxf(duration, 0.05)
	_set_vanish(0.0)
	_vanish_tween = _make_tween()
	_vanish_tween.tween_method(Callable(self, "_set_vanish"), 0.0, 1.0, vanish_time)
	_vanish_tween.tween_callback(_finish_vanish.bind(on_finished))


func _finish_vanish(on_finished: Callable) -> void:
	_vanish_tween = null
	_set_vanish(0.0)
	_set_progress(0.0)
	if on_finished.is_valid():
		on_finished.call()


func _ramp_progress(target: float, duration: float) -> void:
	var start := _get_progress()
	if duration <= 0.0 or is_equal_approx(start, target):
		_set_progress(target)
		return
	_visual_tween = _make_tween()
	_visual_tween.tween_method(Callable(self, "_set_progress"), start, target, duration)


func _get_progress() -> float:
	if _ring_material:
		return _ring_material.get_shader_parameter("progress")
	return 0.0


func _make_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _kill_tweens() -> void:
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	if _vanish_tween and _vanish_tween.is_valid():
		_vanish_tween.kill()
	_visual_tween = null
	_vanish_tween = null


func _on_body_entered(body: Node3D) -> void:
	if _passed:
		return
	if Time.get_ticks_msec() < _cooldown_until_msec:
		return
	if not _is_head_damage_receiver(body):
		return

	var velocity := _get_swim_velocity(body)
	if velocity.length() < min_speed:
		return

	var pass_axis := (global_transform.basis * pass_local_direction).normalized()
	if velocity.normalized().dot(pass_axis) >= direction_dot_threshold:
		_on_pass(body, pass_axis)
	else:
		_on_fail()


func _is_head_damage_receiver(body: Node) -> bool:
	return body is DamageReciever and body.get_parent().name == "XRCamera3D"


func _get_swim_velocity(body: Node) -> Vector3:
	var camera := body.get_parent()
	if camera:
		var undersea = camera.get_node_or_null("UnderseaProcessing")
		if undersea:
			return undersea.currentVelocity

	var node: Node = body
	while node:
		var psm := node.get_node_or_null("PlayerStateMachine") as PlayerStateMachine
		if psm:
			return -psm.currentVelocity
		node = node.get_parent()
	return Vector3.ZERO


func _on_pass(body: Node3D, pass_axis: Vector3) -> void:
	_passed = true
	area.monitoring = false
	_apply_pass_boost(body, pass_axis)
	pass_audio.play()
	_notify_passed()


func _notify_passed() -> void:
	var controller := get_parent() as RaceController
	if controller:
		controller.handle_hoop_passed(self)
	else:
		hoop_passed.emit(self)


func _apply_pass_boost(body: Node3D, direction: Vector3) -> void:
	var psm := _find_player_state_machine(body)
	if psm:
		psm.apply_hoop_pass_boost(direction, pass_boost_speed, pass_boost_decay)


func _find_player_state_machine(body: Node) -> PlayerStateMachine:
	var node: Node = body
	while node:
		var psm := node.get_node_or_null("PlayerStateMachine") as PlayerStateMachine
		if psm:
			return psm
		node = node.get_parent()
	return null


func _on_fail() -> void:
	_cooldown_until_msec = Time.get_ticks_msec() + int(fail_cooldown_sec * 1000.0)
	fail_audio.play()
