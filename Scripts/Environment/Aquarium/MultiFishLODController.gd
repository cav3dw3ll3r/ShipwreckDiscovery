extends Node3D
class_name MultiFishLODController

enum FishLodBucket { NEAR, FAR, CULLED }

@export_group("LOD & Rendering")
@export var near_multimesh_node: MultiMeshInstance3D
@export var far_multimesh_node: MultiMeshInstance3D
@export var near_mesh_material: Material
const lod_distance: float = 12.0
## Wider dead zone around `lod_distance` so fish do not flip near/far every frame (reduces flashing at the boundary).
const lod_hysteresis: float = 3.0
## Beyond this distance (with hysteresis), fish are not drawn on either multimesh. Set <= `lod_distance` to disable culling.
const cull_distance: float = 30.0
const cull_hysteresis: float = 3.0
## When > 0, LOD distance checks use a smoothed copy of the player position (reduces VR / tracking jitter at the LOD ring).
const lod_camera_smoothing = 30.0
## Hysteresis output must stay stable this many consecutive frames before the committed bucket changes (reduces edge pops). 1 = previous behavior.
@export_range(1, 30, 1) var lod_switch_stable_frames: int = 1
@export_range(1, 4096, 1) var render_chunk_size: int = 256
@export_range(1, 16, 1) var far_render_update_interval: int = 2

@export_group("Basic Settings")
@export var spotlight_target: Spotlight_Target
@export var fish_count: int = 1028
@export var swim_radius: float = 40.0
@export var swim_speed: float = 1.5
@export var turn_speed: float = 10.0
@export var yaw_offset: float = -90.0
@export var anchor_group: String = "Anchor"
@export var obstacle_avoid_weight: float = 3.0
@export var avoid_object_distance: float = 2.5
@export var vertical_avoid_weight: float = 5.0
@export var bottom: float = 5.0
@export var ceiling: float = 5.0

@export_group("Behavior")
@export var is_schooling: bool = true
@export var neighbor_radius: float = 3.5
@export var separation_radius: float = 2.5
@export var alignment_weight: float = 0.8
@export var cohesion_weight: float = 0.8
@export var separation_weight: float = 0.9
@export var flee_distance: float = 3.0
@export_range(1, 256, 1) var max_neighbor_samples: int = 48
@export_range(1, 16, 1) var avoidance_update_interval: int = 2

@export_group("Performance Tuning")
@export_range(1, 8, 1) var spatial_grid_update_interval: int = 1

@export_group("Scale")
@export var scale_min: float = 0.9
@export var scale_max: float = 1.1

@export_group("Startup Warmup")
@export var startup_fast_forward_enabled: bool = true
@export_range(0.0, 10.0, 0.1) var startup_fast_forward_duration: float = 2.
@export_range(1.0, 30.0, 0.5) var startup_fast_forward_multiplier: float = 12.0

@export_group("Spawn Safety")
@export_flags_3d_physics var spawn_ground_collision_mask: int = (1 << 0) | (1 << 7)
@export_flags_3d_physics var spawn_ai_blocker_collision_mask: int = (1 << 0) | (1 << 7)
@export_range(1, 32, 1) var spawn_position_max_attempts: int = 8
@export_range(0.1, 20.0, 0.1) var spawn_probe_height: float = 10.0
@export_range(0.5, 100.0, 0.5) var spawn_probe_depth: float = 50.0
@export_range(0.0, 5.0, 0.05) var spawn_surface_clearance: float = 0.35
@export_range(0.05, 3.0, 0.05) var spawn_blocker_radius: float = 0.35

# Enums & Constants
const AVOIDANCE_COLLISION_MASK: int = (1 << 0) | (1 << 7)
## FAR fish cast avoidance rays less often than NEAR fish to reduce physics cost.
const FAR_AVOIDANCE_INTERVAL_MULTIPLIER: int = 1
const FISH_DIRECTIVE = preload("res://Scripts/Environment/Aquarium/Multi_State_Enums.gd").FISH_DIRECTIVE
const logic_budget_ms: float = 1.0
## 3D transform (12) + custom data vec4 (4) when `use_custom_data` is true — must match `multimesh.buffer` size.
const MULTIMESH_STRIDE_FLOATS: int = 16
## Reefs retain a small ambient population at low fish biomass and reach authored density at target biomass.
const MIN_FISH_BIOMASS_COUNT_MULTIPLIER: float = 0.2
## Healthy reefs support larger non-lionfish, up to 50% above authored scale.
const MAX_REEF_HEALTH_FISH_SCALE_MULTIPLIER: float = 1.5

# Memory Buffers for GPU Upload
var near_buffer: PackedFloat32Array
var far_buffer: PackedFloat32Array
## Stable per-fish wave phase for vertex shaders (passed as INSTANCE_CUSTOM.x each frame).
var wave_phase: PackedFloat32Array
## Per-fish LOD bucket with hysteresis (updated in `_process`).
var _lod_bucket: Array[int] = []
## Last hysteresis-proposed bucket while waiting for `lod_switch_stable_frames`.
var _lod_pending_bucket: Array[int] = []
var _lod_switch_streak: Array[int] = []

# Spatial partitioning (mirrors multi_fish_controller)
var grid_array: Array[Array] = []
var _active_cell_indices: Array[int] = []
var grid_width: int
var grid_height: int
var grid_depth: int
var cell_size: float
var grid_origin: Vector3
var neighbor_radius_sq: float
var separation_radius_sq: float
var flee_distance_sq: float
var swim_radius_sq: float
## `positions[i].distance_squared_to(school_center)` above this triggers a reset (avoids bogus `Vector3.length()` from world origin).
var _position_sanity_dist_sq: float = 1e12

# Core Data
var positions: Array[Vector3] = []
var velocities: Array[Vector3] = []
var actual_velocities: Array[Vector3] = []
var scales: Array[float] = []
var other_data_1: Array[float] = []
var other_data_2: Array[float] = []
var other_data_3: Array[float] = []
var current_states: Array[FISH_DIRECTIVE] = []

# Logic Chunking
var current_fish_idx: int = 0
var render_fish_idx: int = 0
var _frame_counter: int = 0
var _physics_frame_counter: int = 0
var _near_buffer_dirty: bool = false
var _far_buffer_dirty: bool = false
var active := false

# Environment Data
var yaw_quat: Quaternion
var school_center: Vector3
var player: Node3D
var _lod_cam_pos: Vector3 = Vector3.ZERO
var _lod_band_warning_emitted: bool = false
## Local-space correction to keep FAR mesh centered like NEAR mesh (handles authoring pivot mismatch).
var _far_mesh_local_offset: Vector3 = Vector3.ZERO
var _avoid_query: PhysicsRayQueryParameters3D
var _spawn_ground_query: PhysicsRayQueryParameters3D
var _spawn_overlap_query: PhysicsShapeQueryParameters3D
var _spawn_overlap_shape := SphereShape3D.new()
var _neighbor_scratch: Array = []
## Scene / inspector instance budget before reef-health scaling (see `_apply_reef_health_fish_count`).
var _authored_fish_count: int = -1
var _game_settings_for_signals: GameSettings
var _startup_warmup_active: bool = false
var _startup_warmup_remaining: float = 0.0

func _ready():
	_apply_near_mesh_material()
	call_deferred("setup_system")
	call_deferred("_connect_game_settings_signal")

func get_spotlight() -> Spotlight_Target:
	return spotlight_target

func get_targetable_transforms() -> Array[Transform3D]:
	var results: Array[Transform3D] = []
	if fish_count <= 0:
		return results
	var yaw_basis := Basis.IDENTITY
	if yaw_quat.length_squared() > 0.0:
		yaw_basis = Basis(yaw_quat)
	results.resize(fish_count)
	for i in fish_count:
		var basis := Basis.IDENTITY
		var pos := school_center
		if i < positions.size():
			pos = positions[i]
		if i < actual_velocities.size():
			var forward: Vector3 = actual_velocities[i]
			if forward.length_squared() < 1e-10:
				forward = Vector3.FORWARD
			else:
				forward = forward.normalized()
			var up_ref := Vector3.UP
			if absf(forward.dot(up_ref)) > 0.92:
				forward = Vector3(forward.x, 0.0, forward.z)
				if forward.length_squared() < 1e-10:
					forward = Vector3.FORWARD
				else:
					forward = forward.normalized()
			var right: Vector3 = up_ref.cross(forward)
			if right.length_squared() < 1e-10:
				right = Vector3.RIGHT
			else:
				right = right.normalized()
			var up: Vector3 = forward.cross(right)
			if up.length_squared() < 1e-10:
				up = up_ref
			else:
				up = up.normalized()
			basis = Basis(right, up, forward) * yaw_basis
		var scale := 1.0
		if i < scales.size():
			scale = scales[i]
		results[i] = Transform3D(basis.scaled(Vector3.ONE * scale), pos)
	return results

func _exit_tree() -> void:
	if _game_settings_for_signals != null and _game_settings_for_signals.on_settings_update.is_connected(_on_game_settings_updated):
		_game_settings_for_signals.on_settings_update.disconnect(_on_game_settings_updated)
		_game_settings_for_signals = null

func _connect_game_settings_signal() -> void:
	var gs := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if gs == null:
		return
	_game_settings_for_signals = gs
	if not gs.on_settings_update.is_connected(_on_game_settings_updated):
		gs.on_settings_update.connect(_on_game_settings_updated)

func _fish_biomass_count_multiplier() -> float:
	var gs := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	var biomass_ratio := 1.0
	if gs != null and gs.has_method("get_current_fish_biomass_ratio"):
		biomass_ratio = gs.get_current_fish_biomass_ratio()
	return lerpf(MIN_FISH_BIOMASS_COUNT_MULTIPLIER, 1.0, clampf(biomass_ratio, 0.0, 1.0))

func _reef_health_fish_scale_multiplier() -> float:
	var gs := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	var health := 1.0
	if gs != null and gs.has_method("get_current_reef_health"):
		health = gs.get_current_reef_health()
	return lerpf(1.0, MAX_REEF_HEALTH_FISH_SCALE_MULTIPLIER, clampf(health, 0.0, 1.0))

func _effective_fish_count_for_biomass() -> int:
	var base: int = _authored_fish_count if _authored_fish_count > 0 else maxi(1, fish_count)
	return maxi(1, roundi(float(base) * _fish_biomass_count_multiplier()))

func _on_game_settings_updated() -> void:
	if _authored_fish_count < 0:
		return
	if _effective_fish_count_for_biomass() == fish_count:
		return
	setup_system()

func _apply_reef_health_fish_count() -> void:
	if _authored_fish_count < 0:
		_authored_fish_count = maxi(1, fish_count)
	fish_count = _effective_fish_count_for_biomass()

func setup_system():
	_apply_reef_health_fish_count()
	randomize()
	yaw_quat = Quaternion(Vector3.UP, deg_to_rad(yaw_offset))
	player = get_tree().get_first_node_in_group("Player")

	var anchor = get_tree().get_first_node_in_group(anchor_group)
	school_center = anchor.global_position if anchor else global_position

	# Spatial grid
	cell_size = neighbor_radius + 1.0
	var total_dim = swim_radius * 2.5
	grid_width = int(total_dim / cell_size)
	grid_height = int(total_dim / cell_size)
	grid_depth = int(total_dim / cell_size)
	var grid_cell_count := grid_width * grid_height * grid_depth
	grid_array.resize(grid_cell_count)
	for c in range(grid_cell_count):
		grid_array[c] = []
	grid_origin = school_center - Vector3(total_dim, total_dim, total_dim) * 0.5

	neighbor_radius_sq = neighbor_radius * neighbor_radius
	separation_radius_sq = separation_radius * separation_radius
	flee_distance_sq = flee_distance * flee_distance
	swim_radius_sq = swim_radius * swim_radius
	var sanity_r: float = maxf(250.0, swim_radius * 12.0)
	_position_sanity_dist_sq = sanity_r * sanity_r

	_avoid_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0, 0, 1), AVOIDANCE_COLLISION_MASK)
	_avoid_query.collide_with_bodies = true
	_avoid_query.hit_from_inside = true
	_spawn_ground_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0, -1, 0), spawn_ground_collision_mask)
	_spawn_ground_query.collide_with_bodies = true
	_spawn_ground_query.hit_from_inside = false
	_spawn_overlap_shape.radius = maxf(0.05, spawn_blocker_radius)
	_spawn_overlap_query = PhysicsShapeQueryParameters3D.new()
	_spawn_overlap_query.shape = _spawn_overlap_shape
	_spawn_overlap_query.collide_with_bodies = true
	_spawn_overlap_query.collide_with_areas = false
	_spawn_overlap_query.collision_mask = spawn_ai_blocker_collision_mask

	# 1. Setup Both MultiMeshes (custom data = stable wave phase for animated fish shaders)
	for mm_node in [near_multimesh_node, far_multimesh_node]:
		if mm_node == null:
			continue
		if mm_node.multimesh == null:
			mm_node.multimesh = MultiMesh.new()
		var mm: MultiMesh = mm_node.multimesh
		mm.instance_count = 0
		mm.use_colors = false
		mm.use_custom_data = true
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = fish_count
		mm_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_lod_mesh_alignment_offset()

	# 2. Allocate bulk arrays (stride = transform + custom data for shaders)
	near_buffer.resize(fish_count * MULTIMESH_STRIDE_FLOATS)
	far_buffer.resize(fish_count * MULTIMESH_STRIDE_FLOATS)
	wave_phase.resize(fish_count)

	# 3. Resize Data Arrays
	positions.resize(fish_count)
	velocities.resize(fish_count)
	actual_velocities.resize(fish_count)
	scales.resize(fish_count)
	current_states.resize(fish_count)
	other_data_1.resize(fish_count)
	other_data_2.resize(fish_count)
	other_data_3.resize(fish_count)
	_lod_bucket.resize(fish_count)
	_lod_pending_bucket.resize(fish_count)
	_lod_switch_streak.resize(fish_count)

	var cam_init = player.global_position if player else school_center
	_lod_cam_pos = cam_init

	var lod_mid_sq = lod_distance * lod_distance
	var cull_mid_sq = cull_distance * cull_distance
	var cull_on := cull_distance > lod_distance + maxf(lod_hysteresis, 0.001)
	var reef_health_scale := _reef_health_fish_scale_multiplier()

	for i in fish_count:
		positions[i] = _generate_safe_spawn_position()
		velocities[i] = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.2), randf_range(-1, 1)).normalized() * swim_speed
		actual_velocities[i] = velocities[i]
		scales[i] = randf_range(scale_min, scale_max) * reef_health_scale
		current_states[i] = FISH_DIRECTIVE.WANDER
		other_data_1[i] = 0.0
		other_data_2[i] = 0.0
		other_data_3[i] = 0.0
		var d0 = positions[i].distance_squared_to(cam_init)
		if d0 < lod_mid_sq:
			_lod_bucket[i] = FishLodBucket.NEAR
		elif not cull_on or d0 < cull_mid_sq:
			_lod_bucket[i] = FishLodBucket.FAR
		else:
			_lod_bucket[i] = FishLodBucket.CULLED
		_lod_pending_bucket[i] = _lod_bucket[i]
		_lod_switch_streak[i] = 0
		wave_phase[i] = randf() * TAU

	_prefill_multimesh_buffers()
	current_fish_idx = 0
	render_fish_idx = 0
	_frame_counter = 0
	_physics_frame_counter = 0
	_apply_near_mesh_material()
	_begin_startup_warmup()
	active = true

func _apply_near_mesh_material() -> void:
	if near_mesh_material == null or near_multimesh_node == null:
		return
	near_multimesh_node.material_override = near_mesh_material

func _update_lod_cam_pos(delta: float) -> void:
	var target := player.global_position if player else school_center
	if lod_camera_smoothing <= 0.0:
		_lod_cam_pos = target
	else:
		var alpha := 1.0 - exp(-lod_camera_smoothing * delta)
		_lod_cam_pos = _lod_cam_pos.lerp(target, clampf(alpha, 0.0, 1.0))

func _lod_squared_thresholds() -> Dictionary:
	var h_nf: float = lod_hysteresis
	var inner_nf_r: float = maxf(0.05, lod_distance - h_nf)
	var outer_nf_r: float = lod_distance + h_nf
	var h_fc: float = cull_hysteresis
	var inner_fc_r: float = maxf(0.05, cull_distance - h_fc)
	var outer_fc_r: float = cull_distance + h_fc

	var culling_active := cull_distance > lod_distance + maxf(h_nf, 0.001)
	if culling_active and inner_fc_r <= outer_nf_r:
		if not _lod_band_warning_emitted:
			push_warning(
				"MultiFishLODController: need cull_distance - cull_hysteresis > lod_distance + lod_hysteresis for a stable FAR band; clamping inner cull radius."
			)
			_lod_band_warning_emitted = true
		inner_fc_r = outer_nf_r + 0.5

	var inner_nf_sq := inner_nf_r * inner_nf_r
	var outer_nf_sq := outer_nf_r * outer_nf_r
	var inner_fc_sq: float
	var outer_fc_sq: float
	if culling_active:
		inner_fc_sq = inner_fc_r * inner_fc_r
		outer_fc_sq = outer_fc_r * outer_fc_r
	else:
		inner_fc_sq = INF
		outer_fc_sq = INF
	return {
		"inner_nf_sq": inner_nf_sq,
		"outer_nf_sq": outer_nf_sq,
		"inner_fc_sq": inner_fc_sq,
		"outer_fc_sq": outer_fc_sq,
		"culling_active": culling_active,
	}

func _hysteresis_next_bucket(current: int, d2: float, inner_nf_sq: float, outer_nf_sq: float, inner_fc_sq: float, outer_fc_sq: float, culling_active: bool) -> int:
	var s: int = current
	if not culling_active and s == FishLodBucket.CULLED:
		s = FishLodBucket.FAR

	match s:
		FishLodBucket.NEAR:
			if d2 >= outer_nf_sq:
				return FishLodBucket.FAR
		FishLodBucket.FAR:
			if d2 <= inner_nf_sq:
				return FishLodBucket.NEAR
			if culling_active and d2 >= outer_fc_sq:
				return FishLodBucket.CULLED
		FishLodBucket.CULLED:
			if culling_active and d2 <= inner_fc_sq:
				return FishLodBucket.FAR
	return s

func _commit_lod_bucket_with_stability(i: int, proposed: int) -> void:
	var need := maxi(1, lod_switch_stable_frames)
	if proposed == _lod_bucket[i]:
		_lod_switch_streak[i] = 0
		_lod_pending_bucket[i] = proposed
		return
	if proposed != _lod_pending_bucket[i]:
		_lod_pending_bucket[i] = proposed
		_lod_switch_streak[i] = 1
	else:
		_lod_switch_streak[i] += 1
	if _lod_switch_streak[i] >= need:
		_lod_bucket[i] = proposed
		_lod_switch_streak[i] = 0

func _fish_basis(i: int) -> Basis:
	var forward: Vector3 = actual_velocities[i]
	if forward.length_squared() < 1e-10:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	# Avoid gimbal-style pops when velocity is nearly vertical.
	var up_ref := Vector3.UP
	if absf(forward.dot(up_ref)) > 0.92:
		forward = Vector3(forward.x, 0.0, forward.z)
		if forward.length_squared() < 1e-10:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
	var right: Vector3 = up_ref.cross(forward)
	if right.length_squared() < 1e-10:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var up: Vector3 = forward.cross(right)
	if up.length_squared() < 1e-10:
		up = up_ref
	else:
		up = up.normalized()
	return Basis(right, up, forward) * Basis(yaw_quat)

func _update_lod_mesh_alignment_offset() -> void:
	_far_mesh_local_offset = Vector3.ZERO
	if not (near_multimesh_node and near_multimesh_node.multimesh and far_multimesh_node and far_multimesh_node.multimesh):
		return
	var near_mesh: Mesh = near_multimesh_node.multimesh.mesh
	var far_mesh: Mesh = far_multimesh_node.multimesh.mesh
	if near_mesh == null or far_mesh == null:
		return
	# Align FAR mesh visual center to NEAR mesh center to avoid apparent teleports on bucket swaps.
	var near_center: Vector3 = near_mesh.get_aabb().get_center()
	var far_center: Vector3 = far_mesh.get_aabb().get_center()
	_far_mesh_local_offset = near_center - far_center

func _append_gpu_instance(i: int, b: Basis, pos: Vector3, scale: float) -> void:
	var slot: int = i * MULTIMESH_STRIDE_FLOATS
	match _lod_bucket[i]:
		FishLodBucket.NEAR:
			transform_buffer_write(near_buffer, slot, b, pos, scale)
			_write_instance_custom_vec4(near_buffer, slot + 12, wave_phase[i])
			_write_hidden_instance(far_buffer, slot, wave_phase[i])
		FishLodBucket.FAR:
			_write_hidden_instance(near_buffer, slot, wave_phase[i])
			var far_pos := pos + (b * (_far_mesh_local_offset * scale))
			transform_buffer_write(far_buffer, slot, b, far_pos, scale)
			_write_instance_custom_vec4(far_buffer, slot + 12, wave_phase[i])
		_:
			_write_hidden_instance(near_buffer, slot, wave_phase[i])
			_write_hidden_instance(far_buffer, slot, wave_phase[i])

func _prefill_multimesh_buffers() -> void:
	for i in fish_count:
		var b := _fish_basis(i)
		_append_gpu_instance(i, b, positions[i], scales[i])
	if near_multimesh_node and near_multimesh_node.multimesh:
		_upload_multimesh_buffer(near_multimesh_node.multimesh, near_buffer)
	if far_multimesh_node and far_multimesh_node.multimesh:
		_upload_multimesh_buffer(far_multimesh_node.multimesh, far_buffer)

func _upload_multimesh_buffer(mm: MultiMesh, buffer: PackedFloat32Array) -> void:
	if mm == null:
		return
	# Guard against runtime count changes: MultiMesh buffer size must exactly match instance_count * stride.
	var expected_instances := int(buffer.size() / MULTIMESH_STRIDE_FLOATS)
	if mm.instance_count != expected_instances:
		mm.instance_count = expected_instances
	mm.visible_instance_count = expected_instances
	mm.buffer = buffer

func _physics_process(delta: float):
	if not active:
		return
	var sim_delta := _effective_sim_delta(delta)

	_physics_frame_counter += 1
	if _physics_frame_counter % maxi(1, spatial_grid_update_interval) == 0:
		update_spatial_grid()

	var start_time = Time.get_ticks_usec()
	var budget = logic_budget_ms * 1000.0
	var processed = 0

	while processed < fish_count:
		_update_fish_logic(current_fish_idx, sim_delta)
		current_fish_idx = (current_fish_idx + 1) % fish_count
		processed += 1
		if Time.get_ticks_usec() - start_time > budget:
			break

func _process(delta: float):
	if not active:
		return
	_update_startup_warmup(delta)
	var sim_delta := _effective_sim_delta(delta)

	_update_lod_cam_pos(delta)
	_frame_counter += 1
	var cam_pos := _lod_cam_pos

	var th := _lod_squared_thresholds()
	var inner_nf_sq: float = th["inner_nf_sq"]
	var outer_nf_sq: float = th["outer_nf_sq"]
	var inner_fc_sq: float = th["inner_fc_sq"]
	var outer_fc_sq: float = th["outer_fc_sq"]
	var culling_active: bool = th["culling_active"]

	var count := mini(fish_count, maxi(1, render_chunk_size))
	for step in count:
		var i := (render_fish_idx + step) % fish_count
		_integrate_fish_pure_data(i, sim_delta)

		var pos = positions[i]
		var scale = scales[i]
		var b := _fish_basis(i)

		var d2: float = pos.distance_squared_to(cam_pos)
		var old_bucket := _lod_bucket[i]
		var proposed := _hysteresis_next_bucket(
			_lod_bucket[i], d2, inner_nf_sq, outer_nf_sq, inner_fc_sq, outer_fc_sq, culling_active
		)
		_commit_lod_bucket_with_stability(i, proposed)
		var bucket_changed := _lod_bucket[i] != old_bucket

		var should_update_slot := true
		if _lod_bucket[i] == FishLodBucket.FAR and not bucket_changed:
			should_update_slot = (_frame_counter + i) % maxi(1, far_render_update_interval) == 0
		elif _lod_bucket[i] == FishLodBucket.CULLED and not bucket_changed:
			should_update_slot = false

		if should_update_slot or bucket_changed:
			_append_gpu_instance(i, b, pos, scale)
			if _lod_bucket[i] == FishLodBucket.NEAR or old_bucket == FishLodBucket.NEAR:
				_near_buffer_dirty = true
			if _lod_bucket[i] == FishLodBucket.FAR or old_bucket == FishLodBucket.FAR:
				_far_buffer_dirty = true

	render_fish_idx = (render_fish_idx + count) % fish_count

	if _near_buffer_dirty and near_multimesh_node and near_multimesh_node.multimesh:
		_upload_multimesh_buffer(near_multimesh_node.multimesh, near_buffer)
		_near_buffer_dirty = false
	if _far_buffer_dirty and far_multimesh_node and far_multimesh_node.multimesh:
		_upload_multimesh_buffer(far_multimesh_node.multimesh, far_buffer)
		_far_buffer_dirty = false

func _begin_startup_warmup() -> void:
	_startup_warmup_active = startup_fast_forward_enabled and startup_fast_forward_duration > 0.0 and startup_fast_forward_multiplier > 1.0
	_startup_warmup_remaining = maxf(0.0, startup_fast_forward_duration)

func _update_startup_warmup(delta: float) -> void:
	if not _startup_warmup_active:
		return
	_startup_warmup_remaining -= maxf(0.0, delta)
	if _startup_warmup_remaining <= 0.0:
		_startup_warmup_active = false
		_startup_warmup_remaining = 0.0

func _effective_sim_delta(delta: float) -> float:
	if _startup_warmup_active:
		return delta * maxf(1.0, startup_fast_forward_multiplier)
	return delta

func _spawn_y_bounds() -> Vector2:
	return Vector2(school_center.y - bottom, school_center.y + ceiling)

func _clamp_spawn_height(pos: Vector3) -> Vector3:
	var y_bounds := _spawn_y_bounds()
	pos.y = clampf(pos.y, y_bounds.x, y_bounds.y)
	return pos

func _random_spawn_candidate() -> Vector3:
	var candidate := school_center + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * swim_radius
	return _clamp_spawn_height(candidate)

func _project_spawn_above_surface(candidate: Vector3) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var from := candidate + Vector3.UP * maxf(0.1, spawn_probe_height)
	var to := candidate - Vector3.UP * maxf(0.1, spawn_probe_depth)
	_spawn_ground_query.from = from
	_spawn_ground_query.to = to
	_spawn_ground_query.collision_mask = spawn_ground_collision_mask
	var hit := space_state.intersect_ray(_spawn_ground_query)
	if hit:
		var adjusted := candidate
		adjusted.y = maxf(adjusted.y, float(hit.position.y) + maxf(0.0, spawn_surface_clearance))
		adjusted = _clamp_spawn_height(adjusted)
		return {"has_surface": true, "position": adjusted}
	return {"has_surface": false, "position": candidate}

func _is_spawn_overlapping_ai_blocker(pos: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	_spawn_overlap_shape.radius = maxf(0.05, spawn_blocker_radius)
	_spawn_overlap_query.transform = Transform3D(Basis.IDENTITY, pos)
	_spawn_overlap_query.collision_mask = spawn_ai_blocker_collision_mask
	var hits := space_state.intersect_shape(_spawn_overlap_query, 1)
	return not hits.is_empty()

func _generate_safe_spawn_position() -> Vector3:
	var max_attempts := maxi(1, spawn_position_max_attempts)
	var fallback := _clamp_spawn_height(school_center)
	for _attempt in range(max_attempts):
		var candidate := _random_spawn_candidate()
		var projection := _project_spawn_above_surface(candidate)
		if not bool(projection["has_surface"]):
			continue
		var pos: Vector3 = projection["position"]
		if _is_spawn_overlapping_ai_blocker(pos):
			continue
		return pos
	if not _is_spawn_overlapping_ai_blocker(fallback):
		return fallback
	# Last-resort fallback: climb inside vertical limits to escape blockers if possible.
	var y_bounds := _spawn_y_bounds()
	var step := maxf(0.25, spawn_blocker_radius)
	var probe := fallback
	while probe.y <= y_bounds.y:
		if not _is_spawn_overlapping_ai_blocker(probe):
			return probe
		probe.y += step
	return fallback

# Pure array math only (thread-friendly): no scene tree, no physics API, no rendering API.
func _integrate_fish_pure_data(i: int, delta: float) -> void:
	if is_nan(positions[i].x) or positions[i].distance_squared_to(school_center) > _position_sanity_dist_sq:
		positions[i] = school_center
		velocities[i] = Vector3.FORWARD * swim_speed
		actual_velocities[i] = velocities[i]
		return
	velocities[i].y = lerp(velocities[i].y, 0.0, delta)
	actual_velocities[i] = actual_velocities[i].lerp(velocities[i], delta * 10.0)
	positions[i] += actual_velocities[i] * delta

func _write_instance_custom_vec4(buffer: PackedFloat32Array, offset: int, phase: float) -> void:
	buffer[offset + 0] = phase
	buffer[offset + 1] = 0.0
	buffer[offset + 2] = 0.0
	buffer[offset + 3] = 1.0

func _write_hidden_instance(buffer: PackedFloat32Array, offset: int, phase: float) -> void:
	# Keep per-fish slot stable while hiding inactive LOD copies.
	transform_buffer_write(buffer, offset, Basis.IDENTITY, school_center, 0.0001)
	_write_instance_custom_vec4(buffer, offset + 12, phase)

func transform_buffer_write(buffer: PackedFloat32Array, offset: int, b: Basis, pos: Vector3, scale: float):
	buffer[offset + 0] = b.x.x * scale
	buffer[offset + 1] = b.y.x * scale
	buffer[offset + 2] = b.z.x * scale
	buffer[offset + 3] = pos.x
	buffer[offset + 4] = b.x.y * scale
	buffer[offset + 5] = b.y.y * scale
	buffer[offset + 6] = b.z.y * scale
	buffer[offset + 7] = pos.y
	buffer[offset + 8] = b.x.z * scale
	buffer[offset + 9] = b.y.z * scale
	buffer[offset + 10] = b.z.z * scale
	buffer[offset + 11] = pos.z

func _update_fish_logic(i: int, delta: float):
	var old_vel = velocities[i]
	check_seek(i)
	var upper_limit = swim_speed * 1.5
	var lower_limit = swim_speed * 0.5

	match current_states[i]:
		FISH_DIRECTIVE.FOLLOW_HEADING:
			_update_align_state(i, delta)
		FISH_DIRECTIVE.WANDER:
			_update_wander_state(i, delta)
		FISH_DIRECTIVE.FLEE:
			upper_limit *= 4.0
			_update_flee_state(i, delta)
		FISH_DIRECTIVE.SEEK:
			_update_seek_state(i, delta)

	var target_vel = velocities[i]
	var avoid = compute_avoidance_force(i)
	var school = Vector3.ZERO

	if avoid.is_zero_approx() and current_states[i] != FISH_DIRECTIVE.FLEE:
		check_flee(i)
		if is_schooling:
			school = _get_schooling_force(i)

	var vert = compute_vertical_constraint(i)
	target_vel += (avoid + school + vert) * delta

	var speed_limit = clamp(target_vel.length(), lower_limit, upper_limit)
	target_vel = target_vel.normalized() * speed_limit

	velocities[i] = old_vel.lerp(target_vel, turn_speed * delta)

# --- Inlined state updates (from Multi_Wander / Multi_Align / Multi_Flee / Multi_Seek) ---

func _update_wander_state(i: int, delta: float):
	other_data_1[i] += delta

	if other_data_1[i] > 1.5:
		other_data_1[i] = 0.0

		var wander_force = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.2, 0.2),
			randf_range(-1.0, 1.0)
		).normalized() * 0.5

		var target_vel = (velocities[i] + wander_force).normalized() * swim_speed
		velocities[i] = target_vel

	if randf() < 0.005:
		var new_heading = velocities[i].rotated(Vector3.UP, randf_range(-PI / 2, PI / 2))
		other_data_1[i] = new_heading.x
		other_data_2[i] = new_heading.y
		other_data_3[i] = new_heading.z
		current_states[i] = FISH_DIRECTIVE.FOLLOW_HEADING

func _update_align_state(i: int, _delta: float):
	var seek_dir = Vector3(
		other_data_1[i],
		other_data_2[i],
		other_data_3[i]
	).normalized()

	velocities[i] = seek_dir * swim_speed

	if velocities[i].normalized().dot(seek_dir) >= 0.95:
		other_data_1[i] = 0.0
		other_data_2[i] = 0.0
		other_data_3[i] = 0.0
		current_states[i] = FISH_DIRECTIVE.WANDER

func _update_flee_state(i: int, _delta: float):
	if not player:
		current_states[i] = FISH_DIRECTIVE.WANDER
		return
	var player_pos = player.global_position
	var fish_pos = positions[i]
	var dist = fish_pos.distance_to(player_pos)
	if dist < 0.001:
		dist = 0.001

	var away_dir = (fish_pos - player_pos).normalized()
	var flee_speed_mult = clamp(flee_distance / dist, 1.0, 2.5)
	velocities[i] = away_dir * (swim_speed * flee_speed_mult)

	if velocities[i].normalized().dot(away_dir) >= 0.85 and dist > flee_distance:
		current_states[i] = FISH_DIRECTIVE.WANDER

func _update_seek_state(i: int, _delta: float):
	var fish_pos = positions[i]
	var center_pos = school_center
	var seek_dir = (center_pos - fish_pos).normalized()

	velocities[i] = seek_dir * swim_speed

	var dist_to_center = fish_pos.distance_to(center_pos)
	if velocities[i].normalized().dot(seek_dir) >= 0.85 and dist_to_center < swim_radius:
		current_states[i] = FISH_DIRECTIVE.WANDER

func update_spatial_grid():
	for idx in _active_cell_indices:
		grid_array[idx].clear()
	_active_cell_indices.clear()

	for i in fish_count:
		var rel_pos = positions[i] - grid_origin
		var gx = clamp(int(rel_pos.x / cell_size), 0, grid_width - 1)
		var gy = clamp(int(rel_pos.y / cell_size), 0, grid_height - 1)
		var gz = clamp(int(rel_pos.z / cell_size), 0, grid_depth - 1)
		var idx = gx + (gy * grid_width) + (gz * grid_width * grid_height)
		var bucket: Array = grid_array[idx]
		if bucket.is_empty():
			_active_cell_indices.append(idx)
		bucket.append(i)

func _get_schooling_force(i: int) -> Vector3:
	_neighbor_scratch.clear()
	var rel_pos_n := positions[i] - grid_origin
	var gx_n := int(rel_pos_n.x / cell_size)
	var gy_n := int(rel_pos_n.y / cell_size)
	var gz_n := int(rel_pos_n.z / cell_size)

	for x in range(max(0, gx_n - 1), min(grid_width, gx_n + 2)):
		for y in range(max(0, gy_n - 1), min(grid_height, gy_n + 2)):
			for z in range(max(0, gz_n - 1), min(grid_depth, gz_n + 2)):
				var nidx := x + (y * grid_width) + (z * grid_width * grid_height)
				_neighbor_scratch.append_array(grid_array[nidx])

	if _neighbor_scratch.size() <= 1:
		return Vector3.ZERO

	var pos := positions[i]
	var vel := velocities[i]

	var align := Vector3.ZERO
	var cohere := Vector3.ZERO
	var separate := Vector3.ZERO
	var count := 0

	var sample_step := maxi(1, int(ceil(float(_neighbor_scratch.size()) / float(maxi(1, max_neighbor_samples)))))
	var sampled := 0
	for idx in range(0, _neighbor_scratch.size(), sample_step):
		var j: int = _neighbor_scratch[idx]
		if i == j:
			continue

		var d2 := pos.distance_squared_to(positions[j])

		if d2 > neighbor_radius_sq:
			continue

		align += velocities[j]
		cohere += positions[j]
		count += 1

		if d2 < separation_radius_sq and d2 > 1e-6:
			var away = pos - positions[j]
			separate += away.normalized() / max(d2, 0.01)
		sampled += 1
		if sampled >= max_neighbor_samples:
			break

	if count == 0:
		return Vector3.ZERO

	align = (align / count).normalized() * swim_speed - vel
	cohere = ((cohere / count) - pos).normalized() * swim_speed - vel

	return (
		align * alignment_weight +
		cohere * cohesion_weight +
		separate * separation_weight
	)

func compute_vertical_constraint(i: int) -> Vector3:
	var pos_y := positions[i].y
	var force := Vector3.ZERO

	var ceiling_y = school_center.y + ceiling
	var floor_y = school_center.y - bottom

	if pos_y > ceiling_y:
		var over = pos_y - ceiling_y
		force.y -= over * vertical_avoid_weight
	elif pos_y < floor_y:
		var under = floor_y - pos_y
		force.y += under * vertical_avoid_weight

	return force

func compute_avoidance_force(i: int) -> Vector3:
	if _lod_bucket.size() == fish_count:
		match _lod_bucket[i]:
			FishLodBucket.CULLED:
				return Vector3.ZERO
			FishLodBucket.FAR:
				var far_interval := maxi(1, avoidance_update_interval * FAR_AVOIDANCE_INTERVAL_MULTIPLIER)
				if (i + _frame_counter) % far_interval != 0:
					return Vector3.ZERO
			_:
				if avoidance_update_interval > 1 and ((i + _frame_counter) % avoidance_update_interval != 0):
					return Vector3.ZERO
	elif avoidance_update_interval > 1 and ((i + _frame_counter) % avoidance_update_interval != 0):
		return Vector3.ZERO
	var space_state := get_world_3d().direct_space_state
	var pos := positions[i]
	var vel := actual_velocities[i]

	if vel.length_squared() < 0.01:
		return Vector3.ZERO

	var forward := vel.normalized()
	var ray_length = avoid_object_distance

	var total_push := Vector3.ZERO
	var hit_count = 0

	_avoid_query.from = pos
	_avoid_query.to = pos + forward * ray_length
	var hit = space_state.intersect_ray(_avoid_query)
	if hit:
		hit_count += 1
		var dist = pos.distance_to(hit.position)
		var t = min(ray_length / dist, 100.0)
		var strength = t * t
		total_push += hit.normal * strength

	if hit_count == 0 or total_push.is_zero_approx():
		return Vector3.ZERO

	return total_push * obstacle_avoid_weight

func check_flee(i):
	if not (player and flee_distance):
		return
	if positions[i].distance_squared_to(player.global_position) <= flee_distance_sq:
		current_states[i] = FISH_DIRECTIVE.FLEE

func check_seek(i):
	if positions[i].distance_squared_to(school_center) >= swim_radius_sq:
		current_states[i] = FISH_DIRECTIVE.SEEK
