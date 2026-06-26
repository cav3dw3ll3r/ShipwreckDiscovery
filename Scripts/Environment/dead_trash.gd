extends Node3D
class_name DeadTrash

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

@export var spear_tube_radius_m: float = 0.086

const _MODEL_SCALE_EPS: float = 1e-4
const _Z_MARGIN_FRAC: float = 0.02
const _FUNNEL_FRAC_OF_SPAN: float = 0.025
const _FUNNEL_WIDTH_MIN: float = 0.002
const _FUNNEL_WIDTH_MAX: float = 0.08
const _SOURCE_SHADER_PARAMS: Array[StringName] = [
	&"albedo_texture",
	&"albedo_tint",
	&"dent_shadow",
	&"metallic",
	&"roughness_multiplier",
	&"normal_strength",
	&"color_strength",
	&"color_brightness",
	&"crumple_strength",
	&"dent_frequency",
	&"crumple_noise_tex",
]

var _dissolve_outro_active: bool = false
var _dissolve_outro_tween: Tween
var _dissolve_outro_material: ShaderMaterial
var _dissolve_audio_player: AudioStreamPlayer3D


func apply_trash_instance_payload(payload: Dictionary) -> void:
	if not is_instance_valid(mesh_instance):
		return
	var source_mesh: Variant = payload.get("trash_mesh", null)
	if source_mesh is Mesh:
		mesh_instance.mesh = source_mesh as Mesh

	var base_mat := mesh_instance.get_active_material(0) as ShaderMaterial
	if base_mat == null:
		return
	var mat := base_mat.duplicate() as ShaderMaterial
	mesh_instance.set_surface_override_material(0, mat)

	var source_material: Variant = payload.get("trash_source_material", null)
	if source_material is ShaderMaterial:
		_copy_live_trash_shader_params(source_material as ShaderMaterial, mat)

	mat.set_shader_parameter("appearance_seed", float(payload.get("trash_appearance_seed", 1.0)))


func _copy_live_trash_shader_params(source: ShaderMaterial, target: ShaderMaterial) -> void:
	for param_name in _SOURCE_SHADER_PARAMS:
		target.set_shader_parameter(param_name, source.get_shader_parameter(param_name))


func apply_spear_tube(spear_tip: Node3D, _hit_world: Vector3) -> void:
	if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
		return
	var base_mat := mesh_instance.get_active_material(0) as ShaderMaterial
	if base_mat == null:
		return
	var mat := base_mat.duplicate() as ShaderMaterial
	mesh_instance.set_surface_override_material(0, mat)

	var mesh_xf: Transform3D = mesh_instance.global_transform
	var pin_local: Vector3 = mesh_xf.affine_inverse() * spear_tip.global_position
	var shaft_world: Vector3 = spear_tip.global_transform.basis.y.normalized()
	var axis_local: Vector3 = mesh_xf.basis.inverse() * shaft_world
	if axis_local.length_squared() > 1.0e-12:
		axis_local = axis_local.normalized()
	else:
		axis_local = Vector3.UP
	mat.set_shader_parameter("local_tube_axis", axis_local)
	mat.set_shader_parameter("local_tube_origin", pin_local)
	mat.set_shader_parameter("insertion_progress", 0.0)

	var aabb: AABB = mesh_instance.get_aabb()
	var z_lo: float = INF
	var z_hi: float = -INF
	if aabb.size.length_squared() > 1.0e-24:
		for ix: int in 2:
			for iy: int in 2:
				for iz: int in 2:
					var corner: Vector3 = aabb.position + Vector3(
						float(ix) * aabb.size.x,
						float(iy) * aabb.size.y,
						float(iz) * aabb.size.z
					)
					var t_ax: float = (corner - pin_local).dot(axis_local)
					z_lo = minf(z_lo, t_ax)
					z_hi = maxf(z_hi, t_ax)
	if z_lo < z_hi:
		var span: float = z_hi - z_lo
		var z_margin: float = maxf(span * _Z_MARGIN_FRAC, 1e-4)
		mat.set_shader_parameter("mesh_z_min", z_lo - z_margin)
		mat.set_shader_parameter("mesh_z_max", z_hi + z_margin)
		var funnel_w: float = clampf(span * _FUNNEL_FRAC_OF_SPAN, _FUNNEL_WIDTH_MIN, _FUNNEL_WIDTH_MAX)
		mat.set_shader_parameter("funnel_width", funnel_w)

	var basis_sc: Vector3 = mesh_xf.basis.get_scale().abs()
	var max_basis_scale: float = maxf(maxf(basis_sc.x, basis_sc.y), basis_sc.z)
	max_basis_scale = maxf(max_basis_scale, _MODEL_SCALE_EPS)
	var tube_r_model: float = spear_tube_radius_m / max_basis_scale
	mat.set_shader_parameter("tube_radius", tube_r_model)


func play_dissolve_outro(duration_sec: float = 2.5, dissolve_audio: AudioStream = null) -> void:
	if _dissolve_outro_active:
		return
	if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
		queue_free()
		return

	var base_mat := mesh_instance.get_active_material(0) as ShaderMaterial
	if base_mat == null:
		queue_free()
		return

	_dissolve_outro_active = true
	_dissolve_outro_material = base_mat.duplicate() as ShaderMaterial
	_dissolve_outro_material.set_shader_parameter("progress", 0.0)
	mesh_instance.set_surface_override_material(0, _dissolve_outro_material)

	if dissolve_audio != null:
		_dissolve_audio_player = AudioStreamPlayer3D.new()
		_dissolve_audio_player.stream = dissolve_audio
		_dissolve_audio_player.volume_db = -20.0
		_dissolve_audio_player.unit_size = 4.0
		_dissolve_audio_player.max_db = 10.0
		_dissolve_audio_player.bus = &"SFX"
		add_child(_dissolve_audio_player)
		_dissolve_audio_player.play()

	if duration_sec <= 0.0:
		_apply_dissolve_outro_progress(1.0)
		queue_free()
		return

	if is_instance_valid(_dissolve_outro_tween):
		_dissolve_outro_tween.kill()

	_dissolve_outro_tween = create_tween()
	_dissolve_outro_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_dissolve_outro_tween.tween_method(_apply_dissolve_outro_progress, 0.0, 1.0, duration_sec)
	_dissolve_outro_tween.finished.connect(_on_dissolve_outro_tween_finished, CONNECT_ONE_SHOT)


func _apply_dissolve_outro_progress(t: float) -> void:
	if is_instance_valid(_dissolve_outro_material):
		_dissolve_outro_material.set_shader_parameter("progress", clampf(t, 0.0, 1.0))


func _on_dissolve_outro_tween_finished() -> void:
	_dissolve_outro_tween = null
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_dissolve_outro_tween):
			_dissolve_outro_tween.kill()
			_dissolve_outro_tween = null
