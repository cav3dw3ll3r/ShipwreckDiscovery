extends MOBehavior

class_name FloorTrackingBehavior

@export var target_height_min = 2.0
@export var target_height_max = 10.0
var wave_control:Waves
var target_depth = 0.0

func start(owner:Node3D) -> void:
	wave_control = owner.get_tree().get_first_node_in_group("Waves")

func compute(owner: Node3D, delta: float) -> void:
	var height := 0.0

	# === Compute the height using a long (1000m) raycast downward ===
	var space_state = owner.get_world_3d().direct_space_state
	var from = owner.global_position
	var to = from + Vector3.DOWN * 1000.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	
	if result:
		height = owner.global_position.y-result.position.y
		# === end raycast ==
		if height < target_height_min:
			owner.global_position.y = lerpf(owner.global_position.y, result.position.y + target_height_min, delta * blend_factor)
		elif height > target_height_max:
			owner.global_position.y = lerpf(owner.global_position.y, result.position.y + target_height_max, delta * blend_factor)
	# If no raycast hit, you are probably underground
	else:
		owner.global_position.y+=delta*10
		
func stop(owner:Node3D) -> void:
	pass
