@tool
extends EditorScript

var scenes: Array[PackedScene] = [load("res://Meshes/Fish/Destin/Lionfish/lionfish_proxy.tscn")]
var count: int = 50

var area_center: Vector3 = Vector3(0, 0, 0)
var area_size: Vector2 = Vector2(40, 40)

var ray_height: float = 40.0
var max_distance: float = 160.0

# Circumnavigate: ray origins on a circle around the wreck; cast downward toward center + random xz offset
var circumnavigate_radius: float = 25.0  # radius of circle around center for ray origins (e.g. outside wreck)

# Shelter filtering: prefer cracks, crevices, under things
var use_shelter_filter: bool = false  # if true, also require non-flat surface and/or overhead cover
var max_placement_attempts: int = 500
var shelter_normal_max_dot: float = 0.95  # accept if normal.dot(UP) <= this; 0.95 = slight slope counts, 0.6 = only steep/walls
var require_overhead_cover: bool = true
var overhead_ray_length: float = 3.0

# Optional: e.g. "Aquarium/Lionfish" to place under a specific node
var parent_path: String = "Aquarium/Lionfish"

# Layer 16 = bit 15
const LAYER_16_MASK := 1 << 15


func _run():
	if scenes.is_empty():
		push_warning("No PackedScenes assigned.")
		return

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		push_warning("No scene root.")
		return

	var parent_node: Node = root
	if parent_path.is_empty() == false:
		if root.has_node(parent_path):
			parent_node = root.get_node(parent_path)
		else:
			push_warning("parent_path '%s' not found; placing under scene root." % parent_path)

	var center := area_center
	var instant_dive := root.get_tree().get_nodes_in_group("InstantDive")
	if not instant_dive.is_empty():
		center = instant_dive[0].global_position
		center.y = 0.0

	var space_state = root.get_world_3d().direct_space_state
	var placed := 0

	for i in count:
		var scene = scenes.pick_random()
		if not scene:
			continue

		var placed_this := false
		for attempt in max_placement_attempts:
			# Circumnavigate: origin on a circle around the wreck, always pointing down toward it
			var angle := randf() * TAU
			var ray_origin := center + Vector3(cos(angle) * circumnavigate_radius, ray_height, sin(angle) * circumnavigate_radius)
			# End point: center + random xz offset, below the origin (down toward wreck)
			var target_xz := Vector3(
				randf_range(-area_size.x * 0.5, area_size.x * 0.5),
				0.0,
				randf_range(-area_size.y * 0.5, area_size.y * 0.5)
			)
			var target := center + target_xz + Vector3(0.0, -max_distance, 0.0)
			var dir := (target - ray_origin).normalized()
			var ray_end := ray_origin + dir * max_distance

			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, LAYER_16_MASK)
			query.collide_with_areas = false

			var hit = space_state.intersect_ray(query)
			if hit.is_empty():
				continue

			# Shelter check: prefer non-flat surfaces and/or overhead cover (skip if filter disabled)
			if use_shelter_filter:
				var sheltered_by_normal = hit.normal.dot(Vector3.UP) <= shelter_normal_max_dot
				var has_overhead := _check_overhead(space_state, hit)
				var passes_shelter = (sheltered_by_normal or has_overhead) and (not require_overhead_cover or has_overhead)
				if not passes_shelter:
					continue

			var instance = scene.instantiate()
			instance.global_position = hit.position
			instance.rotation.y = randf_range(0.0, 360.0)
			parent_node.add_child(instance)
			instance.owner = root
			placed += 1
			placed_this = true
			break

		if not placed_this:
			push_warning("Sheltered placement: no valid spot found after %d attempts for instance %d." % [max_placement_attempts, i + 1])



func _check_overhead(space_state: PhysicsDirectSpaceState3D, hit: Dictionary) -> bool:
	# Start slightly off the surface so we don't self-hit; do NOT exclude hit collider so
	# "underside of ledge" counts as overhead (upward ray hits the ledge above us)
	var origin = hit.position + hit.normal * 0.05
	var end = origin + Vector3.UP * overhead_ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, end, LAYER_16_MASK)
	query.collide_with_areas = false
	var overhead_hit := space_state.intersect_ray(query)
	return not overhead_hit.is_empty()
