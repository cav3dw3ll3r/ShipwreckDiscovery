@tool
extends XRToolsPickable
class_name ZookeeperPickable

## Emitted whenever the driven shader uniform advances during capture outro (0–1).
signal capture_outro_progress_changed(progress: float)

@export_group("Capture outro dissolve")
@export var capture_outro_duration_sec: float = 2.5
## Uniform tweened during outro ([code]flashaway_black_plastic[/code] uses [code]progress[/code]).
@export var capture_outro_shader_param: StringName = &"progress"
@export var capture_outro_transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var capture_outro_ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Capture squish audio (rubber-band style)")
## Tip axial speed (m/s) into the tube at which squish begins.
@export var capture_squish_speed_for_min: float = 0.05
## Tip axial speed (m/s) at which squish reaches max volume/pitch.
@export var capture_squish_speed_for_max: float = 1.5
@export var capture_squish_min_volume_db: float = -24.0
@export var capture_squish_max_volume_db: float = 2.0
@export var capture_squish_min_pitch_scale: float = 0.85
@export var capture_squish_max_pitch_scale: float = 1.25
## When pulling back along the tube (negative axial velocity), extra quietness vs push-in.
@export var capture_squish_reverse_volume_db_offset: float = -12.0
@export var capture_squish_reverse_pitch_scale: float = 0.95

@export_group("Lite Grab Hands")
@export var left_hand_grab_point_mesh: Node3D
@export var right_hand_grab_point_mesh: Node3D

@onready var _squish_player: AudioStreamPlayer3D = $SquishPlayer
@onready var _dissolve_player: AudioStreamPlayer3D = $DissolvePlayer

var _spear: RevisedSpearPickable
var _allow_forced_release: bool = false
var _is_capturing: bool = false

## Prevents overlapping finalization passes.
var _capture_outro_started: bool = false
var _capture_outro_materials: Array[ShaderMaterial] = []
var _capture_outro_tween: Tween

var _capture_trigger: Area3D
var _capture_bottom_target: Node3D
var _capture_mouth_target: Node3D
var _capture_axis_end_target: Node3D
var _capture_snag_target: Node3D
var _captured_fish_anchor: Node3D

func bind_spear(spear: RevisedSpearPickable) -> void:
	_spear = spear


func get_bound_spear() -> RevisedSpearPickable:
	return _spear


func prepare_for_forced_off_hand_teardown() -> void:
	_allow_forced_release = true
	_is_capturing = false
	reset_capture_squish_audio()


func find_spear_trophy() -> Node3D:
	if not is_instance_valid(_spear):
		return null
	return _spear.get_spear_trophy()


func get_captured_fish_parent() -> Node3D:
	# Parent to the RB so fish depth follows cage motion; axial placement uses tube math in SpearCapturedState.
	return self


func _ready() -> void:
	super()
	grabbed.connect(_on_zookeeper_grabbed)
	_capture_trigger = get_node_or_null("CaptureTrigger") as Area3D
	_capture_bottom_target = get_node_or_null("CaptureBottomTarget") as Node3D
	_capture_mouth_target = get_node_or_null("CaptureMouthTarget") as Node3D
	_capture_axis_end_target = get_node_or_null("CaptureAxisEndTarget") as Node3D
	_capture_snag_target = get_node_or_null("CaptureSnagTarget") as Node3D
	_captured_fish_anchor = get_node_or_null("CapturedFishAnchor") as Node3D
	
	if _capture_trigger:
		_capture_trigger.area_entered.connect(_on_capture_trigger_area_entered)


func _on_zookeeper_grabbed(_pickable: XRToolsPickable, by: Node3D) -> void:
	show_lite_hand_for_pickup(by)


func show_lite_hand_for_pickup(pickup: Node3D) -> void:
	var is_left_hand := false
	var controller := XRHelpers.get_xr_controller(pickup)
	if controller:
		is_left_hand = controller.tracker == &"left_hand"
	else:
		is_left_hand = "left" in pickup.name.to_lower()
	_set_lite_hand_visible(left_hand_grab_point_mesh, is_left_hand)
	_set_lite_hand_visible(right_hand_grab_point_mesh, not is_left_hand)


func hide_lite_hands() -> void:
	_set_lite_hand_visible(left_hand_grab_point_mesh, false)
	_set_lite_hand_visible(right_hand_grab_point_mesh, false)


func _set_lite_hand_visible(mesh_node: Node3D, is_visible: bool) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.visible = is_visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_capture_outro_tween):
			_capture_outro_tween.kill()
			_capture_outro_tween = null
		if _squish_player and _squish_player.playing:
			_squish_player.stop()
		if _dissolve_player and _dissolve_player.playing:
			_dissolve_player.stop()


func _on_capture_trigger_area_entered(area: Area3D) -> void:
	if _capture_outro_started or _is_capturing or not is_instance_valid(_spear):
		return
	if not area.is_in_group("spear_tip_capture"):
		return
		
	# Only start if the spear is currently loaded and ready to be captured
	if _spear.current_state is SpearLoadedState:
		_is_capturing = true
		_spear.change_state(SpearCapturedState.new(), {
			"zookeeper": self,
			"mouth_target": _capture_mouth_target,
			"snag_target": _capture_snag_target,
			"axis_end_target": _capture_axis_end_target
		})


func reset_receptacle() -> void:
	# Called by the Spear if the player pulls the spear back out
	_is_capturing = false
	reset_capture_squish_audio()


func reset_capture_squish_audio() -> void:
	if _squish_player and _squish_player.playing:
		_squish_player.stop()


func update_capture_squish_from_tip_axial_velocity(velocity_m_s: float) -> void:
	if not _squish_player:
		return
	var denom := capture_squish_speed_for_max - capture_squish_speed_for_min
	if denom <= 0.0:
		return

	if velocity_m_s > 0.0:
		var stretch_speed_m_s := velocity_m_s
		var t := clampf((stretch_speed_m_s - capture_squish_speed_for_min) / denom, 0.0, 1.0)
		if t <= 0.0:
			reset_capture_squish_audio()
			return
		_squish_player.volume_db = lerpf(capture_squish_min_volume_db, capture_squish_max_volume_db, t)
		_squish_player.pitch_scale = lerpf(capture_squish_min_pitch_scale, capture_squish_max_pitch_scale, t)
		if not _squish_player.playing:
			_squish_player.play()
	elif velocity_m_s < 0.0:
		var pull_speed_m_s := -velocity_m_s
		var t2 := clampf((pull_speed_m_s - capture_squish_speed_for_min) / denom, 0.0, 1.0)
		if t2 <= 0.0:
			reset_capture_squish_audio()
			return
		_squish_player.volume_db = lerpf(capture_squish_min_volume_db, capture_squish_max_volume_db, t2) + capture_squish_reverse_volume_db_offset
		_squish_player.pitch_scale = lerpf(capture_squish_min_pitch_scale, capture_squish_max_pitch_scale, t2) * capture_squish_reverse_pitch_scale
		if not _squish_player.playing:
			_squish_player.play()
	else:
		reset_capture_squish_audio()


func _play_dissolve_and_stop_squish() -> void:
	reset_capture_squish_audio()
	if not _dissolve_player or _dissolve_player.stream == null:
		return
	if _dissolve_player.playing:
		_dissolve_player.stop()
	_dissolve_player.play()


func finalize_capture() -> void:
	if _capture_outro_started:
		return
	_capture_outro_started = true

	_allow_forced_release = true
	if is_picked_up():
		drop()
		hide_lite_hands()
		
	if is_instance_valid(_spear):
		var pickup = _spear.get_off_hand_pickup()
		if is_instance_valid(pickup) and pickup.picked_up_object == self:
			pickup.drop_object()
	
	enabled = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true

	if _capture_trigger:
		_capture_trigger.set_deferred(&"monitoring", false)

	_prepare_capture_outro_materials()

	if capture_outro_duration_sec <= 0.0:
		_apply_capture_outro_progress(1.0)
		_play_dissolve_and_stop_squish()
		queue_free()
		return

	if _capture_outro_materials.is_empty():
		_play_dissolve_and_stop_squish()
		queue_free()
		return

	if is_instance_valid(_capture_outro_tween):
		_capture_outro_tween.kill()
	
	_capture_outro_tween = create_tween()
	_capture_outro_tween.set_trans(capture_outro_transition).set_ease(capture_outro_ease)
	_apply_capture_outro_progress(0.0)
	_play_dissolve_and_stop_squish()
	
	_capture_outro_tween.tween_method(_apply_capture_outro_progress, 0.0, 1.0, capture_outro_duration_sec)
	_capture_outro_tween.finished.connect(_on_capture_outro_tween_finished, CONNECT_ONE_SHOT)


func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	if _capture_outro_started:
		super.let_go(by, p_linear_velocity, p_angular_velocity)
		return
	if _is_capturing and not _allow_forced_release:
		call_deferred("_restore_pickup_ref_after_blocked_let_go", by)
		return
	super.let_go(by, p_linear_velocity, p_angular_velocity)


func _restore_pickup_ref_after_blocked_let_go(pickup: Node3D) -> void:
	if not is_instance_valid(self) or not is_instance_valid(pickup) or _allow_forced_release:
		return
	if pickup is XRToolsFunctionPickup:
		pickup.picked_up_object = self


func _shader_material_has_uniform(mat: ShaderMaterial, param_name: StringName) -> bool:
	var sh := mat.shader
	if sh == null:
		return false
	for u in sh.get_shader_uniform_list():
		if param_name == StringName(String(u.get("name", ""))):
			return true
	return false


func _mesh_instance_is_under_spear_trophy(mi: MeshInstance3D) -> bool:
	var p: Node = mi.get_parent()
	while p:
		if p.is_in_group("spear_trophy"):
			return true
		p = p.get_parent()
	return false


func _handoff_capture_trophies_to_dummy_anchor() -> void:
	if not is_instance_valid(_spear):
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	if _spear.loaded_state_exploding_dummy_scene != null:
		var holder := _spear.loaded_state_exploding_dummy_scene.instantiate() as Node3D
		if holder == null:
			return
		scene_root.add_child(holder)
		holder.global_transform = global_transform
		RevisedSpearPickable.reparent_spear_trophies_zk_to_dummy(self, holder, _spear)
	else:
		RevisedSpearPickable.reparent_spear_trophies_zk_to_dummy(self, scene_root, _spear)


func _append_capture_outro_mesh_material_dups(trophies_only: bool) -> void:
	var param_name := capture_outro_shader_param
	for mi in find_children("*", "MeshInstance3D", true, false):
		if not mi is MeshInstance3D:
			continue
		var mesh_inst := mi as MeshInstance3D
		if _mesh_instance_is_under_spear_trophy(mesh_inst) != trophies_only:
			continue

		var mo := mesh_inst.material_override
		if mo is ShaderMaterial:
			var smo := mo as ShaderMaterial
			if _shader_material_has_uniform(smo, param_name):
				var dup_o := smo.duplicate() as ShaderMaterial
				dup_o.set_shader_parameter(param_name, 0.0)
				mesh_inst.material_override = dup_o
				_capture_outro_materials.append(dup_o)
			continue

		var mesh := mesh_inst.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var mat := mesh_inst.get_active_material(si)
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				if not _shader_material_has_uniform(sm, param_name):
					continue
				var dup := sm.duplicate() as ShaderMaterial
				dup.set_shader_parameter(param_name, 0.0)
				mesh_inst.set_surface_override_material(si, dup)
				_capture_outro_materials.append(dup)


func _prepare_capture_outro_materials() -> void:
	_capture_outro_materials.clear()
	_append_capture_outro_mesh_material_dups(true)
	_handoff_capture_trophies_to_dummy_anchor()
	_append_capture_outro_mesh_material_dups(false)


func _apply_capture_outro_progress(t: float) -> void:
	var p := clampf(t, 0.0, 1.0)
	for mat in _capture_outro_materials:
		mat.set_shader_parameter(capture_outro_shader_param, p)
	capture_outro_progress_changed.emit(p)


func _on_capture_outro_tween_finished() -> void:
	_capture_outro_tween = null
	queue_free()
