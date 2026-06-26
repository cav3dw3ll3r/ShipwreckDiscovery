extends RefCounted
class_name ShelteredScatterPlacer

## Layer 16 (wreck mesh) + layer 8 (Atlantis AIBlocking collision).
const PLACEMENT_LAYER_MASK := (1 << 15) | (1 << 7)

var area_center: Vector3 = Vector3.ZERO
var area_size: Vector2 = Vector2(40, 40)
var ray_height: float = 40.0
var max_distance: float = 160.0
var circumnavigate_radius: float = 25.0
var use_shelter_filter: bool = false
var max_placement_attempts: int = 500
var shelter_normal_max_dot: float = 0.95
var require_overhead_cover: bool = true
var overhead_ray_length: float = 3.0
var randomize_y_rotation: bool = true
var randomize_scale: bool = false
var scale_min: float = 0.9
var scale_max: float = 1.1


func scatter(tree: SceneTree, count: int) -> Array[Transform3D]:
	var results: Array[Transform3D] = []
	if count <= 0:
		return results

	var center := _resolve_center(tree)
	var space_state := tree.root.get_world_3d().direct_space_state

	for i in count:
		var placed := false
		for _attempt in max_placement_attempts:
			var angle := randf() * TAU
			var ray_origin := center + Vector3(
				cos(angle) * circumnavigate_radius,
				ray_height,
				sin(angle) * circumnavigate_radius
			)
			var target_xz := Vector3(
				randf_range(-area_size.x * 0.5, area_size.x * 0.5),
				0.0,
				randf_range(-area_size.y * 0.5, area_size.y * 0.5)
			)
			var target := center + target_xz + Vector3(0.0, -max_distance, 0.0)
			var dir := (target - ray_origin).normalized()
			var ray_end := ray_origin + dir * max_distance

			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, PLACEMENT_LAYER_MASK)
			query.collide_with_areas = false

			var hit := space_state.intersect_ray(query)
			if hit.is_empty():
				continue

			if use_shelter_filter:
				var sheltered_by_normal = hit.normal.dot(Vector3.UP) <= shelter_normal_max_dot
				var has_overhead := _check_overhead(space_state, hit)
				var passes_shelter = (sheltered_by_normal or has_overhead) and (not require_overhead_cover or has_overhead)
				if not passes_shelter:
					continue

			var hit_position: Vector3 = hit.position
			var xf := Transform3D(Basis.IDENTITY, hit_position)
			if randomize_y_rotation:
				xf.basis = xf.basis.rotated(Vector3.UP, deg_to_rad(randf_range(0.0, 360.0)))
			if randomize_scale:
				var s := randf_range(scale_min, scale_max)
				xf.basis = xf.basis.scaled(Vector3(s, s, s))

			results.append(xf)
			placed = true
			break

		if not placed:
			push_warning("ShelteredScatterPlacer: no valid spot after %d attempts for instance %d." % [max_placement_attempts, i + 1])

	return results


func _resolve_center(tree: SceneTree) -> Vector3:
	var instant_dive := tree.get_nodes_in_group("InstantDive")
	if not instant_dive.is_empty():
		var center: Vector3 = instant_dive[0].global_position
		center.y = 0.0
		return center
	return area_center


func _check_overhead(space_state: PhysicsDirectSpaceState3D, hit: Dictionary) -> bool:
	var origin = hit.position + hit.normal * 0.05
	var end = origin + Vector3.UP * overhead_ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, end, PLACEMENT_LAYER_MASK)
	query.collide_with_areas = false
	return not space_state.intersect_ray(query).is_empty()
