extends MOBehavior

class_name LateralAvoidanceBehavior

@export var detection_distance = 1.0
@export var avoidance_speed = 60.0

var wave_control:Waves
var target_depth = 0.0

var is_avoiding:bool = false
var is_turning_right:bool = true

func start(owner:Node3D) -> void:
	wave_control = owner.get_tree().get_first_node_in_group("Waves")

func compute(owner: Node3D, delta: float) -> void:
	# === Avoid objects in front of the fish by turning only on the Y axis ===
	var space_state = owner.get_world_3d().direct_space_state

	# Cast a ray straight ahead (local forward = -Z in Godot)
	var forward_dir = -owner.global_transform.basis.z.normalized()
	var ray_origin = owner.global_position
	var ray_end = ray_origin + forward_dir * 5.0 + Vector3.UP *0.5 # detection distance in meters

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [owner] # don't hit self

	var result = space_state.intersect_ray(query)

	if result:
		if not is_avoiding:
			#TODO: Figure out which way to turn to most easily avoid the obstacle
			var normal = result.normal
			var right_dir = owner.global_transform.basis.x
			var dot = normal.dot(right_dir)
			is_turning_right = dot<0.0 # If the random number is even, we are turning right.
		var avoid_angle = deg_to_rad(avoidance_speed) # how sharply to turn
		# Rotate only around the Y axis (yaw)
		var current_rot = owner.rotation
		if is_turning_right:
			current_rot.y += avoid_angle * delta
		else:
			current_rot.y -= avoid_angle * delta
		owner.rotation = current_rot
		is_avoiding = true
	else:
		is_avoiding = false
	# === end avoidance ===

func stop(owner:Node3D) -> void:
	pass
