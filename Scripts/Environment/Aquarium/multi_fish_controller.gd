extends MultiMeshInstance3D
class_name MultiFishController

@export_group("Basic Settings")
@export var android_mesh: Mesh
@export var shared_material: Material
@export var spotlight_target: Node3D # Changed to Node3D for broader compatibility, adjust if you have a specific class
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

@export_group("Scale")
@export var scale_min: float = 0.9
@export var scale_max: float = 1.1

# Enums & Constants
## Raycast obstacle query: project physics layers 1 and 8 only (bits 0 and 7).
const AVOIDANCE_COLLISION_MASK: int = (1 << 0) | (1 << 7)
const FISH_DIRECTIVE = preload("res://Scripts/Environment/Aquarium/Multi_State_Enums.gd").FISH_DIRECTIVE
const yaw_rad = -1.5708 # Pre-calculated -90 degrees
const logic_budget_ms: float = 1.0
const VISUAL_CHUNK: int = 256  # Max multimesh updates per frame to cap app time
## 3D transform (12) + custom data vec4 (4) when `use_custom_data` is true.
const MULTIMESH_STRIDE_FLOATS: int = 16
## Reefs retain a small ambient population at low fish biomass and reach authored density at target biomass.
const MIN_FISH_BIOMASS_COUNT_MULTIPLIER: float = 0.2
## Healthy reefs support larger non-lionfish, up to 50% above authored scale.
const MAX_REEF_HEALTH_FISH_SCALE_MULTIPLIER: float = 1.5

## 1 = integrate every fish every frame; 2 or 4 = stagger position integration
var _position_phase_stride: int = 1
var _wreck_lod: int = 0
## Scene / inspector instance budget before reef-health scaling.
var _authored_fish_count: int = -1
var _game_settings_for_signals: GameSettings

# Spatial Partitioning Data
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

# Core Data
var positions: Array[Vector3] = []
var velocities: Array[Vector3] = []
var actual_velocities: Array[Vector3] = []
var scales: Array[float] = []
var other_data_1: Array[float] = []
var other_data_2: Array[float] = []
var other_data_3: Array[float] = []
var current_states: Array[FISH_DIRECTIVE] = []
var current_fish_idx: int = 0
var _visual_offset: int = 0  # Spread multimesh updates over frames
var yaw_quat: Quaternion
var school_center: Vector3
var player: Node3D
var active := false
var _avoid_sphere := SphereShape3D.new()

# The Bulk Upload Buffer
var transform_buffer: PackedFloat32Array
## Stable per-fish wave phase for vertex shaders (INSTANCE_CUSTOM.x); not derived from position or INSTANCE_ID.
var wave_phase: PackedFloat32Array

# Temp vars to prevent memory allocation in loops
var _neighbor_scratch: Array = []
var _avoid_query: PhysicsRayQueryParameters3D

func _ready():
	if OS.get_name() == "Android":
		fish_count = fish_count / 2
		if android_mesh:
			multimesh.mesh = android_mesh
	if shared_material:
		multimesh.mesh.surface_set_material(0, shared_material)
	_avoid_sphere.radius = 0.5
	call_deferred("setup_system")
	call_deferred("_connect_game_settings_signal")

func _exit_tree() -> void:
	if _game_settings_for_signals != null and _game_settings_for_signals.on_settings_update.is_connected(_on_game_settings_updated):
		_game_settings_for_signals.on_settings_update.disconnect(_on_game_settings_updated)
		_game_settings_for_signals = null

func get_targetable_transforms() -> Array[Transform3D]:
	var results: Array[Transform3D] = []
	var mm := multimesh
	if mm == null:
		return results
	var count := mm.instance_count
	for i in count:
		results.append(mm.get_instance_transform(i))
	return results

func get_spotlight():
	return spotlight_target

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
	
	# Assuming LOD_Manager exists in your project scope
	if player and player.has_method("is_wreck_lod_active") and player.is_wreck_lod_active() and player.has_signal("wreck_lod_changed"):
		_wreck_lod = maxi(0, player.wreck_lod_level)
		_apply_wreck_lod_stride()
		if not player.wreck_lod_changed.is_connected(_on_wreck_lod_changed):
			player.wreck_lod_changed.connect(_on_wreck_lod_changed)

	var anchor = get_tree().get_first_node_in_group(anchor_group)
	school_center = anchor.global_position if anchor else global_position
	
	# Setup Spatial Grid Dimensions
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

	_avoid_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0, 0, 1), AVOIDANCE_COLLISION_MASK)
	_avoid_query.collide_with_bodies = true
	_avoid_query.hit_from_inside = true

	# Initialize MultiMesh (custom data = stable wave phase for animated fish shaders)
	multimesh.instance_count = 0
	multimesh.use_custom_data = true
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = fish_count

	transform_buffer.resize(fish_count * MULTIMESH_STRIDE_FLOATS)
	wave_phase.resize(fish_count)

	# Resize Arrays
	positions.resize(fish_count)
	velocities.resize(fish_count)
	actual_velocities.resize(fish_count)
	scales.resize(fish_count)
	current_states.resize(fish_count)
	other_data_1.resize(fish_count)
	other_data_2.resize(fish_count)
	other_data_3.resize(fish_count)
	var reef_health_scale := _reef_health_fish_scale_multiplier()

	for i in fish_count:
		positions[i] = school_center + Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * swim_radius
		velocities[i] = Vector3(randf_range(-1,1), randf_range(-0.2,0.2), randf_range(-1,1)).normalized() * swim_speed
		scales[i] = randf_range(scale_min, scale_max) * reef_health_scale
		current_states[i] = FISH_DIRECTIVE.WANDER
		wave_phase[i] = randf() * TAU

		# Initial populate of the buffer to prevent zero-scaled invisible fish on frame 1
		_update_visual_transform(i)

	current_fish_idx = 0
	_visual_offset = 0
	active = true

func _on_wreck_lod_changed(level: int) -> void:
	_wreck_lod = maxi(0, level)
	_apply_wreck_lod_stride()

func _apply_wreck_lod_stride() -> void:
	match _wreck_lod:
		0: _position_phase_stride = 1
		1: _position_phase_stride = 2
		_: _position_phase_stride = 4

func _physics_process(delta: float):
	if not active: return
	
	update_spatial_grid()
	
	var start_time = Time.get_ticks_usec()
	var budget = logic_budget_ms * 1000.0
	var processed = 0
	
	while processed < fish_count:
		_update_fish_logic(current_fish_idx, delta)
		current_fish_idx = (current_fish_idx + 1) % fish_count
		processed += 1
		
		if Time.get_ticks_usec() - start_time > budget:
			break

func _process(delta: float):
	if not active: return

	var stride: int = maxi(1, _position_phase_stride)
	var pos_dt: float = delta * float(stride)
	var phase: int = Engine.get_process_frames() % stride

	for i in fish_count:
		# --- SAFETY CHECK ---
		if is_nan(positions[i].x) or positions[i].length() > 500.0:
			positions[i] = school_center
			velocities[i] = Vector3.FORWARD * swim_speed
			continue

		velocities[i].y = lerp(velocities[i].y, 0.0, delta)
		actual_velocities[i] = actual_velocities[i].lerp(velocities[i], delta * 10.0)
		
		# Stagger position integration when wreck is mid/far
		if stride == 1 or (i % stride) == phase:
			positions[i] += actual_velocities[i] * pos_dt

		# Write math to our raw array (no GPU API calls here)
		var visual_idx := (i - _visual_offset + fish_count) % fish_count
		if visual_idx < VISUAL_CHUNK:
			_update_visual_transform(i)

	_visual_offset = (_visual_offset + VISUAL_CHUNK) % fish_count

	# THE ARCHITECT'S MOVE: Single Bulk Upload to the GPU per frame.
	multimesh.buffer = transform_buffer

func _update_fish_logic(i: int, delta: float):
	var old_vel = velocities[i]
	check_seek(i)
	var upper_limit = swim_speed * 1.5
	var lower_limit = swim_speed * 0.5
	
	# Assuming MultiAlign, MultiWander, etc., are singletons or static classes handling the state modification
	match current_states[i]:
		FISH_DIRECTIVE.FOLLOW_HEADING: MultiAlign.update(i, delta, self)
		FISH_DIRECTIVE.WANDER: MultiWander.update(i, delta, self)
		FISH_DIRECTIVE.FLEE:
			upper_limit *= 4.0 
			MultiFlee.update(i, delta, self)
		FISH_DIRECTIVE.SEEK: 
			MultiSeek.update(i, delta, self)

	var target_vel = velocities[i] 
	var avoid = compute_avoidance_force(i)
	var school = Vector3.ZERO
	
	if avoid.is_zero_approx() and current_states[i] != FISH_DIRECTIVE.FLEE:
		check_flee(i)
		school = _get_schooling_force(i) if is_schooling else Vector3.ZERO

	var vert = compute_vertical_constraint(i)
	target_vel += (avoid + school + vert) * delta

	var speed_limit = clamp(target_vel.length(), lower_limit, upper_limit)
	target_vel = target_vel.normalized() * speed_limit

	velocities[i] = old_vel.lerp(target_vel, turn_speed * delta) # Use the turn_speed export var

# --- Optimized Visual Buffer Writing ---

func _update_visual_transform(i: int):
	var forward = actual_velocities[i].normalized()
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	
	var right = Vector3.UP.cross(forward).normalized()
	var up = forward.cross(right).normalized()
	
	# Create the Basis and apply Yaw and Scale. 
	# Creating one local Basis struct in GDScript is extremely fast.
	var b = Basis(right, up, forward) * Basis(yaw_quat)
	b = b.scaled(Vector3.ONE * scales[i])
	
	# Godot's internal MultiMesh memory layout for a 3D Transform is Row-Major.
	# Row 0: Basis X.x, Basis Y.x, Basis Z.x, Origin.x
	# Row 1: Basis X.y, Basis Y.y, Basis Z.y, Origin.y
	# Row 2: Basis X.z, Basis Y.z, Basis Z.z, Origin.z
	var offset: int = i * MULTIMESH_STRIDE_FLOATS

	# Row 0
	transform_buffer[offset + 0] = b.x.x
	transform_buffer[offset + 1] = b.y.x
	transform_buffer[offset + 2] = b.z.x
	transform_buffer[offset + 3] = positions[i].x

	# Row 1
	transform_buffer[offset + 4] = b.x.y
	transform_buffer[offset + 5] = b.y.y
	transform_buffer[offset + 6] = b.z.y
	transform_buffer[offset + 7] = positions[i].y

	# Row 2
	transform_buffer[offset + 8] = b.x.z
	transform_buffer[offset + 9] = b.y.z
	transform_buffer[offset + 10] = b.z.z
	transform_buffer[offset + 11] = positions[i].z

	# INSTANCE_CUSTOM (wave phase); must stay in sync with bulk buffer stride
	transform_buffer[offset + 12] = wave_phase[i]
	transform_buffer[offset + 13] = 0.0
	transform_buffer[offset + 14] = 0.0
	transform_buffer[offset + 15] = 1.0

# --- Optimized Spatial Grid Helpers ---

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

# --- Internal Math ---

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

	for j in _neighbor_scratch:
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
		var strength = t * t  # quadratic falloff
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
