@tool
extends Path3D
class_name RaceController

var DEFAULT_HOOP_SCENE := load("res://Prefabs/Environment/hoop.tscn")

signal race_finished(result: FishRaceResult)

@export var racer_visual: PackedScene
@export var racer_audio: AudioStream

@export_group("Race")
@export var race_id: String = ""
@export var hoop_scene: PackedScene = DEFAULT_HOOP_SCENE
@export var hoop: NodePath = ^"Hoop"
@export var checkpoint_count: int = 4
@export var start_offset_along: float = 0.0
@export var travel_duration: float = 1.5
@export var target_time: float = 120.0
@export var racer_duration: float = 120.0
@export var hoop_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var timeout_vanish_duration: float = 0.4

var _hoop: Node3D
var _racer: Node3D
var _racer_audio_player: AudioStreamPlayer3D
var _racer_distance: float = 0.0
var _distance_along: float = 0.0
var _checkpoints_cleared: int = 0
var _time_remaining: float = 0.0
var _waiting_for_player: bool = false
var _race_active: bool = false
var _race_finished: bool = false
var _race_start_msec: int = 0
var _travel_tween: Tween
var _racer_tween: Tween
var _handling_hoop_pass := false

func _ready() -> void:
	_ensure_hoop()
	_setup_hoop_at_checkpoint_one()
	queue_free()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _race_active or _race_finished:
		return
	if not _waiting_for_player:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_on_checkpoint_timeout()

func _ensure_hoop() -> void:
	if not hoop.is_empty():
		_hoop = get_node_or_null(hoop) as Node3D
	if _hoop:
		return

	for child in get_children():
		if child.name == "Racer":
			continue
		if child.has_method("set_waiting"):
			_hoop = child
			return

	if hoop_scene:
		_hoop = hoop_scene.instantiate() as Node3D
		_hoop.name = "Hoop"
		_hoop.scale = hoop_scale
		add_child(_hoop)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			_hoop.owner = get_tree().edited_scene_root

func _ensure_racer() -> bool:
	if not racer_visual:
		return false

	if is_instance_valid(_racer):
		return true

	var existing := get_node_or_null(^"Racer") as Node3D
	if existing:
		_racer = existing
	else:
		var instance := racer_visual.instantiate()
		if not instance is Node3D:
			push_warning("RaceController: racer_visual root must be a Node3D.")
			if instance:
				instance.queue_free()
			return false
		_racer = instance as Node3D
		_racer.name = "Racer"
		add_child(_racer)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			_racer.owner = get_tree().edited_scene_root

	_disable_racer_physics(_racer)
	_set_node_visible(_racer, true)
	return true


func _ensure_racer_audio() -> void:
	if is_instance_valid(_racer_audio_player):
		return
	_racer_audio_player = get_node_or_null(^"RacerAudio") as AudioStreamPlayer3D
	if _racer_audio_player == null:
		_racer_audio_player = AudioStreamPlayer3D.new()
		_racer_audio_player.name = "RacerAudio"
		add_child(_racer_audio_player)
	if racer_audio:
		_racer_audio_player.stream = racer_audio


func _set_node_visible(node: Node, visible: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = visible
	elif node is MeshInstance3D:
		(node as MeshInstance3D).visible = visible
	for child in node.get_children():
		_set_node_visible(child, visible)


func _hide_racer() -> void:
	if is_instance_valid(_racer):
		_set_node_visible(_racer, false)
	if is_instance_valid(_racer_audio_player):
		_racer_audio_player.stop()

func _disable_racer_physics(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_disable_racer_physics(child)

func _setup_hoop_at_checkpoint_one() -> void:
	if curve == null or curve.get_point_count() == 0:
		return
	_kill_travel_tween()
	_kill_racer_tween()
	_waiting_for_player = false
	_distance_along = start_offset_along
	_checkpoints_cleared = 0
	_race_finished = false
	_race_active = false
	_place_on_curve(_hoop, _distance_along, hoop_scale)

	if _hoop and _hoop.has_method("set_waiting"):
		_hoop.set_waiting()

	_hide_racer()


func _place_on_curve(node: Node3D, distance: float, node_scale:Vector3 = Vector3.ONE) -> void:
	if node == null or curve == null:
		return
	var baked_len := curve.get_baked_length()
	if baked_len <= 0.0:
		return

	var d := clampf(distance, 0.0, baked_len)
	var path_xform := curve.sample_baked_with_rotation(d, true)
	node.position = path_xform.origin
	node.basis = path_xform.basis.orthonormalized()
	node.scale = node_scale


func _racer_scale() -> Vector3:
	return Vector3(
		1.0 / hoop_scale.x if hoop_scale.x > 0.0001 else 1.0,
		1.0 / hoop_scale.y if hoop_scale.y > 0.0001 else 1.0,
		1.0 / hoop_scale.z if hoop_scale.z > 0.0001 else 1.0
	)


func _sync_racer_audio_at_distance(distance: float) -> void:
	if not is_instance_valid(_racer_audio_player) or curve == null:
		return
	var baked_len := curve.get_baked_length()
	if baked_len <= 0.0:
		return
	var d := clampf(distance, 0.0, baked_len)
	_racer_audio_player.position = curve.sample_baked_with_rotation(d, true).origin


func _activate_race() -> void:
	if _race_active or _race_finished:
		return
	_race_active = true
	_race_start_msec = Time.get_ticks_msec()
	call_deferred("_begin_racer_run")


func _begin_racer_run() -> void:
	if Engine.is_editor_hint() or not _race_active or _race_finished:
		return
	_start_racer()


func _start_racer() -> void:
	if not racer_visual or curve == null:
		return
	if not _ensure_racer():
		return

	_ensure_racer_audio()
	_kill_racer_tween()
	_racer_distance = 0.0
	_set_node_visible(_racer, true)
	_place_on_curve(_racer, _racer_distance, _racer_scale())

	var baked_len := curve.get_baked_length()
	if baked_len <= 0.0:
		push_warning("RaceController: curve baked length is 0; racer will not move.")
		return

	_sync_racer_audio_at_distance(_racer_distance)
	if _racer_audio_player and racer_audio:
		if _racer_audio_player.playing:
			_racer_audio_player.stop()
		_racer_audio_player.play()

	_racer_tween = create_tween()
	_racer_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_racer_tween.tween_method(
		Callable(self, "_on_racer_distance_changed"),
		0.0,
		baked_len,
		maxf(racer_duration, 0.01)
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func _on_racer_distance_changed(distance: float) -> void:
	_racer_distance = distance
	if is_instance_valid(_racer):
		_place_on_curve(_racer, distance, _racer_scale())
	_sync_racer_audio_at_distance(distance)

func _stop_racer_at_finish() -> void:
	_kill_racer_tween()
	if not is_instance_valid(_racer) or curve == null:
		return
	var baked_len := curve.get_baked_length()
	_racer_distance = baked_len
	_place_on_curve(_racer, baked_len, _racer_scale())
	if is_instance_valid(_racer_audio_player):
		_racer_audio_player.stop()

func handle_hoop_passed(hoop_node: Node) -> void:
	if _handling_hoop_pass or _race_finished:
		return
	_handling_hoop_pass = true

	_waiting_for_player = false

	if not _race_active:
		_activate_race()

	_checkpoints_cleared += 1

	if _checkpoints_cleared >= checkpoint_count:
		_finish_race()
		_handling_hoop_pass = false
		return

	_advance_hoop_along_curve()
	_handling_hoop_pass = false

func _checkpoint_spacing() -> float:
	if curve == null or checkpoint_count <= 0:
		return 0.0
	var baked_len := curve.get_baked_length()
	if baked_len <= start_offset_along:
		return 0.0
	return (baked_len - start_offset_along) / float(checkpoint_count)


func _advance_hoop_along_curve() -> void:
	if _hoop == null or curve == null:
		return

	var target_distance := minf(_distance_along + _checkpoint_spacing(), curve.get_baked_length())

	if is_equal_approx(target_distance, _distance_along):
		_on_travel_finished(target_distance)
		return

	if _hoop.has_method("set_travelling"):
		_hoop.set_travelling()

	_kill_travel_tween()
	_travel_tween = create_tween()
	_travel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_travel_tween.tween_method(
		Callable(self, "_on_travel_distance_changed"),
		_distance_along,
		target_distance,
		travel_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_travel_tween.tween_callback(_on_travel_finished.bind(target_distance))

func _on_travel_distance_changed(distance: float) -> void:
	_distance_along = distance
	_place_on_curve(_hoop, distance, hoop_scale)

func _on_travel_finished(target_distance: float) -> void:
	_distance_along = target_distance
	_place_on_curve(_hoop, target_distance, hoop_scale)

	if _hoop and _hoop.has_method("set_waiting"):
		_hoop.set_waiting()

	_time_remaining = target_time
	_waiting_for_player = true

func _on_checkpoint_timeout() -> void:
	if _race_finished:
		return
	_waiting_for_player = false
	if _hoop and _hoop.has_method("play_vanish"):
		_hoop.play_vanish(timeout_vanish_duration, _setup_hoop_at_checkpoint_one)
	else:
		_setup_hoop_at_checkpoint_one()

func _finish_race() -> void:
	_race_finished = true
	_race_active = false
	_waiting_for_player = false
	_kill_travel_tween()
	_stop_racer_at_finish()

	if _hoop and _hoop.has_method("play_vanish"):
		_hoop.play_vanish(timeout_vanish_duration, Callable())

	var elapsed := (Time.get_ticks_msec() - _race_start_msec) / 1000.0
	var result := _make_race_result(elapsed)
	_emit_race_finished(result)

func _make_race_result(elapsed_sec: float) -> FishRaceResult:
	var result := FishRaceResult.new()
	result.race_id = _resolve_race_id()
	result.elapsed_sec = elapsed_sec
	result.checkpoint_count = checkpoint_count
	result.checkpoints_cleared = _checkpoints_cleared
	result.race_controller = self
	return result

func _resolve_race_id() -> String:
	if not race_id.is_empty():
		return race_id
	if not name.is_empty():
		return name
	if not scene_file_path.is_empty():
		return scene_file_path.get_file().get_basename()
	return "fish_race"

func _emit_race_finished(result: FishRaceResult) -> void:
	race_finished.emit(result)
	if not Engine.is_editor_hint():
		SignalBus.fish_race_finished.emit(result)

func _kill_travel_tween() -> void:
	if _travel_tween and _travel_tween.is_valid():
		_travel_tween.kill()
	_travel_tween = null

func _kill_racer_tween() -> void:
	if _racer_tween and _racer_tween.is_valid():
		_racer_tween.kill()
	_racer_tween = null
