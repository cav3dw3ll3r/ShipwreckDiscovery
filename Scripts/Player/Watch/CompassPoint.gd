## DEPRECATED: Not used in Optimized_Base / going forward; kept for reference.
extends Node3D

@export var rotation_speed: float = 0.5  # how fast to interpolate toward north

@onready var actual_north = get_tree().get_first_node_in_group("North")  # your North marker
@onready var compass_north = $N

func _process(delta: float) -> void:
	var center = global_transform.origin
	var forward_dir = global_transform.basis.z.normalized()
	const ANGLE_LIMIT_DEG = 30.0
	var up_dot = forward_dir.dot(Vector3.UP)

	if up_dot < cos(deg_to_rad(ANGLE_LIMIT_DEG)):
		return
	var v1 = (center - compass_north.global_transform.origin)
	v1.y = 0
	if v1.length_squared() == 0:
		return
	v1 = v1.normalized()

	var v2 = (actual_north.global_transform.origin - center)
	v2.y = 0
	if v2.length_squared() == 0:
		return
	v2 = v2.normalized()

	var dot = clamp(v1.dot(v2), -1.0, 1.0)
	var cross = v1.cross(v2)
	var error_angle = atan2(cross.y, dot)

	if abs(error_angle) < 0.02:
		rotation.z = round(rotation.z * 100.0) / 100.0
		return

	# smooth correction (no double subtraction!)
	rotation.z = lerp_angle(rotation.z, rotation.z + error_angle, delta * rotation_speed)
