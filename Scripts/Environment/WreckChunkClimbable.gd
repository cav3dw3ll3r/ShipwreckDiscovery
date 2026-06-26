extends Node3D
# One chunk of a wreck assembler prefab: has a Spotlight_Target and reports itself
# for SolidClimbableSpotlight. Mesh LOD: near/mid/far by distance to player.

@export var spotlight_target: Spotlight_Target

# Distance thresholds (m): below near_distance = near_mesh, between = mid_mesh, above mid_distance = far_mesh.
# Chunks are fairly large, so give them generous activation margins.
@export var near_distance: float = 15.
@export var mid_distance: float = 25.0
# View priority: chunks within the angle get one LOD promotion. Near distance uses wider angle; beyond view_priority_distance uses stricter angle.
@export var view_priority_angle_near: float = 50.0
@export var view_priority_angle_far: float = 50.
@export var view_priority_distance: float = 10.0
@export var frame_pressure_threshold_ms: float = 10.0
@export var frame_pressure_hysteresis_ms: float = 0.5
@export var frame_time_smoothing_speed: float = 3.5
@export var pressured_near_distance_scale: float = 0.8
@export var pressured_view_priority_angle_scale: float = 0.85

const LOD_TICK_HZ := 7  # Coprime with other spotlights to spread load
const _PHASE_SPREAD := 97  # Prime: stagger chunk ticks so they do not align on the same frame

var _mesh_instance: MeshInstance3D
var _player: Node3D
var _lod_tick_accumulator: float = 0.0
var _avg_app_time_ms: float = 0.0
var _frame_pressure_active: bool = false

func _ready() -> void:
	add_to_group("climbable")
	_mesh_instance = _find_or_create_mesh_instance()
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	# Spread initial phase so dozens of chunks do not all call _update_mesh_by_distance together.
	var tick_period := 1.0 / float(LOD_TICK_HZ)
	_lod_tick_accumulator = (float(abs(hash(str(get_path()))) % _PHASE_SPREAD) / float(_PHASE_SPREAD)) * tick_period
	_update_mesh_by_distance()
	_apply_shared_material()

func _find_or_create_mesh_instance() -> MeshInstance3D:
	var mi := _get_first_mesh_instance(self)
	if mi == null and spotlight_target != null:
		mi = MeshInstance3D.new()
		add_child(mi)
		var mesh: Mesh = spotlight_target.near_mesh if spotlight_target.near_mesh else spotlight_target.mid_mesh if spotlight_target.mid_mesh else spotlight_target.far_mesh
		if mesh:
			mi.mesh = mesh
			_apply_shared_material()
	return mi

func _get_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _get_first_mesh_instance(c)
		if found != null:
			return found
	return null

func _process(delta: float) -> void:
	_update_frame_time_pressure(delta)
	_lod_tick_accumulator += delta
	var interval := 1.0 / float(LOD_TICK_HZ)
	while _lod_tick_accumulator >= interval:
		_update_mesh_by_distance()
		_lod_tick_accumulator -= interval

func _update_frame_time_pressure(delta: float) -> void:
	var fps := float(Engine.get_frames_per_second())
	var frame_time_ms = 1000.0 / max(1.0, fps)
	if _avg_app_time_ms <= 0.0:
		_avg_app_time_ms = frame_time_ms
	else:
		var alpha = clamp(frame_time_smoothing_speed * delta, 0.0, 1.0)
		_avg_app_time_ms = lerp(_avg_app_time_ms, frame_time_ms, alpha)
	var enter_threshold := frame_pressure_threshold_ms
	var exit_threshold = max(0.0, frame_pressure_threshold_ms - frame_pressure_hysteresis_ms)
	if _frame_pressure_active:
		if _avg_app_time_ms < exit_threshold:
			_frame_pressure_active = false
	else:
		if _avg_app_time_ms > enter_threshold:
			_frame_pressure_active = true

func _update_mesh_by_distance() -> void:
	if _mesh_instance == null or spotlight_target == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node3D
		if _player == null:
			return
	var dist_sq := global_position.distance_squared_to(_player.global_position)
	var effective_near_distance := near_distance * (pressured_near_distance_scale if _frame_pressure_active else 1.0)
	var near_sq := effective_near_distance * effective_near_distance
	var mid_sq := mid_distance * mid_distance
	var mesh: Mesh = null
	if dist_sq <= near_sq:
		mesh = spotlight_target.near_mesh
	elif dist_sq <= mid_sq:
		mesh = spotlight_target.mid_mesh
	else:
		mesh = spotlight_target.far_mesh
	# View priority: promote LOD by one level when chunk is in view; use stricter angle for distant chunks
	var to_chunk := global_position - _player.global_position
	if not to_chunk.is_zero_approx():
		var forward := -_player.global_transform.basis.z
		var view_angle_deg := rad_to_deg(forward.angle_to(to_chunk.normalized()))
		var dist := sqrt(dist_sq)
		var angle_limit := view_priority_angle_near if dist <= view_priority_distance else view_priority_angle_far
		if _frame_pressure_active and dist <= view_priority_distance:
			angle_limit *= pressured_view_priority_angle_scale
		if view_angle_deg <= angle_limit:
			if mesh == spotlight_target.mid_mesh and spotlight_target.near_mesh != null:
				mesh = spotlight_target.near_mesh
			elif mesh == spotlight_target.far_mesh and spotlight_target.mid_mesh != null:
				mesh = spotlight_target.mid_mesh
	if mesh == null:
		mesh = spotlight_target.near_mesh if spotlight_target.near_mesh else spotlight_target.mid_mesh if spotlight_target.mid_mesh else spotlight_target.far_mesh
	if mesh != null and _mesh_instance.mesh != mesh:
		_mesh_instance.mesh = mesh
		_apply_shared_material()

func _apply_shared_material() -> void:
	if _mesh_instance == null or spotlight_target == null or _mesh_instance.mesh == null:
		return
	var mat: Material = null
	var current_mesh: Mesh = _mesh_instance.mesh
	if current_mesh == spotlight_target.near_mesh and spotlight_target.near_material != null:
		mat = spotlight_target.near_material
	elif current_mesh == spotlight_target.mid_mesh and spotlight_target.mid_material != null:
		mat = spotlight_target.mid_material
	elif current_mesh == spotlight_target.far_mesh and spotlight_target.far_material != null:
		mat = spotlight_target.far_material
	if mat == null:
		mat = spotlight_target.shared_material
	if mat != null:
		_mesh_instance.set_surface_override_material(0, mat)

func get_spotlight() -> Spotlight_Target:
	return spotlight_target

func get_targetable_transforms() -> Array[Transform3D]:
	return [global_transform]
