extends RefCounted
class_name ScannerRadar


const UNSELECTED_TARGET_IDX := 50
const MAX_TARGET_DISTANCE := 10.0

var scan_point: Node3D
var spotlight: EntitySpotlight
var display_material: ShaderMaterial
var audio_player: AudioStreamPlayer3D

var max_angle_deg: float = 60.0
var target_idx: int = UNSELECTED_TARGET_IDX
var scan_progress: float = 0.0
var is_scanning: bool = false
var was_interrupted: bool = false

var _projected := PackedVector3Array()
var _was_trig_pressed: bool = false


func world_to_radar_uv(world_pos: Vector3, scanner: Node3D, cone_deg: float = 60.0) -> Vector3:
	var to_obj: Vector3 = world_pos - scanner.global_position
	var inv := scanner.global_transform.basis.inverse()
	var local: Vector3 = inv * to_obj

	if local.z < 0:
		return Vector3(-1, -1, -1)

	var angle_x := rad_to_deg(atan2(local.x, local.z))
	var angle_y := rad_to_deg(atan2(local.y, local.z))
	var u = -1.0 * clamp(angle_x / cone_deg, -1.0, 1.0)
	var v = clamp(angle_y / cone_deg, -1.0, 1.0)
	return Vector3(u * 0.5 + 0.5, 1.0 - (v * 0.5 + 0.5), to_obj.length())


func update_fish(world_positions: Array[Vector3]) -> void:
	if scan_point == null or display_material == null:
		return

	_projected.clear()
	var closest_dist := INF
	var projected_idx := 0
	target_idx = UNSELECTED_TARGET_IDX

	for pos in world_positions:
		var uvd := world_to_radar_uv(pos, scan_point, max_angle_deg)
		if uvd.x < 0.0 or uvd.x > 1.0 or uvd.y < 0.0 or uvd.y > 1.0:
			continue
		_projected.append(uvd)
		if uvd.z < closest_dist:
			closest_dist = uvd.z
			target_idx = projected_idx
		projected_idx += 1

	if closest_dist > MAX_TARGET_DISTANCE:
		target_idx = UNSELECTED_TARGET_IDX
		if is_scanning:
			was_interrupted = true

	display_material.set_shader_parameter("count", _projected.size())
	display_material.set_shader_parameter("angular_positions", _projected)
	display_material.set_shader_parameter("tgt_idx", target_idx)
	display_material.set_shader_parameter("scan_progress", scan_progress)


func update_display(tree: SceneTree) -> void:
	if spotlight == null and tree != null:
		spotlight = tree.get_first_node_in_group("Spotlight") as EntitySpotlight
	if spotlight == null:
		update_fish([])
		return

	var positions: Array[Vector3] = []
	for t: Transform3D in spotlight.spotlight_transforms:
		positions.append(t.origin)
	update_fish(positions)


func handle_trigger_input(left_controller: XRController3D) -> void:
	if left_controller == null or spotlight == null:
		return

	var trigger_pressed := left_controller.is_button_pressed("trigger")

	if trigger_pressed and not is_scanning and not _was_trig_pressed:
		is_scanning = true
		scan_progress = 0.0
		spotlight.is_locked = true
		if audio_player != null:
			audio_player.play()
	elif (not trigger_pressed and is_scanning) or was_interrupted:
		is_scanning = false
		scan_progress = 0.0
		spotlight.is_locked = false
		if audio_player != null:
			audio_player.stop()
		was_interrupted = false

	_was_trig_pressed = trigger_pressed


## Returns spotlight target when a scan completes this frame, otherwise null.
func tick_scan(delta: float) -> Spotlight_Target:
	if not is_scanning:
		return null

	scan_progress += delta
	if scan_progress < 1.0:
		return null

	was_interrupted = true
	if spotlight == null or target_idx >= spotlight.spotlight_targets.size():
		return null
	return spotlight.spotlight_targets[target_idx]


func get_target_world_position() -> Vector3:
	if spotlight == null or target_idx >= spotlight.spotlight_transforms.size():
		return Vector3.ZERO
	return spotlight.spotlight_transforms[target_idx].origin
