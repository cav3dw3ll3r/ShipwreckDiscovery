extends Node

class_name EyelidDamageImpulse

@export var eyelids_mesh: MeshInstance3D
@export_range(0.0, 1.0, 0.001) var open_rest_impulse: float = 0.05
@export_range(0.0, 1.0, 0.001) var half_close_progress: float = 0.3
@export_range(0.01, 2.0, 0.01) var close_time: float = 0.08
@export_range(0.01, 2.0, 0.01) var open_time: float = 0.2
@export_range(0.0, 2.0, 0.01) var intensity_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var impulse_noise_strength: float = 0.08
@export_range(0.0, 1.0, 0.01) var intensity_noise_strength: float = 0.2
@export_range(1.0, 60.0, 0.1) var noise_scale: float = 18.0
@export_range(0.0, 8.0, 0.01) var noise_speed: float = 2.6

var _material: ShaderMaterial
var _pulse_epoch: int = 0
var _current_impulse: float = 0.0
var _current_intensity: float = 0.0
var _noise_seed: float = 1.0


func _ready() -> void:
	randomize()
	if not eyelids_mesh:
		eyelids_mesh = get_parent() as MeshInstance3D
	if not eyelids_mesh:
		return
	_material = eyelids_mesh.get_active_material(0) as ShaderMaterial
	_current_impulse = clampf(open_rest_impulse, 0.0, 1.0)
	_sync_noise_params()
	_apply_damage_uniforms(_current_impulse, 0.0)


func play_damage_pulse(strength: float = 1.0) -> void:
	if not _material:
		return
	_pulse_epoch += 1
	var epoch := _pulse_epoch
	var clamped_strength := clampf(strength, 0.0, 2.0)
	_noise_seed = randf() * 1000.0
	_sync_noise_params()
	_material.set_shader_parameter("damage_noise_seed", _noise_seed)
	_run_damage_pulse(epoch, clamped_strength)


func _run_damage_pulse(epoch: int, strength: float) -> void:
	var base_impulse := clampf(open_rest_impulse, 0.0, 1.0)
	var target_impulse := clampf(base_impulse + (half_close_progress * strength), 0.0, 1.0)
	var target_intensity := clampf(strength * intensity_multiplier, 0.0, 1.0)
	await _animate_value(epoch, _current_impulse, target_impulse, _current_intensity, target_intensity, close_time)
	await _animate_value(epoch, _current_impulse, base_impulse, _current_intensity, 0.0, open_time)


func _animate_value(
	epoch: int,
	from_impulse: float,
	to_impulse: float,
	from_intensity: float,
	to_intensity: float,
	duration: float
) -> void:
	if duration <= 0.0:
		_current_impulse = to_impulse
		_current_intensity = to_intensity
		_apply_damage_uniforms(_current_impulse, _current_intensity)
		return

	var start_time := Time.get_ticks_usec()
	while true:
		if epoch != _pulse_epoch:
			return
		var elapsed := (Time.get_ticks_usec() - start_time) / 1000000.0
		var t := clampf(elapsed / duration, 0.0, 1.0)
		var eased := t * t * (3.0 - (2.0 * t))
		_current_impulse = lerpf(from_impulse, to_impulse, eased)
		_current_intensity = lerpf(from_intensity, to_intensity, eased)
		_apply_damage_uniforms(_current_impulse, _current_intensity)
		if t >= 1.0:
			return
		await get_tree().process_frame


func _apply_damage_uniforms(impulse: float, intensity: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("damage_impulse", clampf(impulse, 0.0, 1.0))
	_material.set_shader_parameter("damage_intensity", clampf(intensity, 0.0, 1.0))


func _sync_noise_params() -> void:
	if not _material:
		return
	_material.set_shader_parameter("damage_noise_impulse_strength", impulse_noise_strength)
	_material.set_shader_parameter("damage_noise_intensity_strength", intensity_noise_strength)
	_material.set_shader_parameter("damage_noise_scale", noise_scale)
	_material.set_shader_parameter("damage_noise_speed", noise_speed)
