extends Node3D
class_name WorldScanner

@export var scan_distance: float = 100.0

func scan() -> Dictionary:
	var result = {}
	var space_state = get_world_3d().direct_space_state

	var from = global_position
	var direction = global_transform.basis.z.normalized()
	var end = from + direction * scan_distance

	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = end
	query.collision_mask = 0x40
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]

	var hit = space_state.intersect_ray(query)

	if hit:
		var collider = hit.get("collider")
		if collider and collider.has_method("get_scannable"):
			result["Scannable"] = collider.get_scannable() as Scannable
		if collider is ScanTarget:
			result["ScanTarget"] = collider as ScanTarget

	return result
