extends Area3D

## The speed/dampening of the rotation
@export var rotation_speed := 1.0
## If true, movement is limited to the Y-axis (spinning like a record)
@export var horizontal_swipe_only := true
## The XRTools controller script checks for this variable
@export var press_to_hold := true

var grabbed_by: Node3D = null
var initial_hand_pos:Vector3 = Vector3.ZERO
var initial_object_angle: float = 0.0

# ----------------------------------------------------------------
# XRTools Interface
# ----------------------------------------------------------------
# Add this to your Rotatable UI script
func is_climbable() -> bool:
	return false
func is_picked_up():
	return grabbed_by != null

func is_xr_class(name: String) -> bool:
	return name == "XRToolsPickable" or name == "RotatableUI"

func can_pick_up(_by: Node3D) -> bool:
	return true

func pick_up(by: Node3D) -> void:
	grabbed_by = by
	initial_hand_pos = by.global_position

func let_go(_by: Node, _linear_vel: Vector3 = Vector3.ZERO, _angular_vel: Vector3 = Vector3.ZERO) -> void:
	grabbed_by = null

func request_highlight(_by: Node3D, _enabled: bool) -> void:
	pass

# ----------------------------------------------------------------
# Logic
# ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not grabbed_by:
		return

	# Hand delta in local space
	var local_hand_delta = to_local(grabbed_by.global_transform.origin) - to_local(initial_hand_pos)

	var delta_rotation_y = local_hand_delta.x * rotation_speed

	if horizontal_swipe_only:
		if rotation_speed >= 1.0:
			rotation.y += delta_rotation_y
		else:
			rotation.y = lerp_angle(rotation.y, rotation.y + delta_rotation_y, rotation_speed * delta)
	else:
		var delta_rotation_x = -local_hand_delta.y * rotation_speed
		if rotation_speed >= 1.0:
			rotation.x += delta_rotation_x
			rotation.y += delta_rotation_y
		else:
			rotation.x = lerp_angle(rotation.x, rotation.x + delta_rotation_x, rotation_speed * delta)
			rotation.y = lerp_angle(rotation.y, rotation.y + delta_rotation_y, rotation_speed * delta)

	# Update reference position for next frame
	initial_hand_pos = grabbed_by.global_transform.origin



## Helper to find the angle of the hand in the object's local space
func _get_hand_angle() -> float:
	# Convert hand position to local coordinates relative to the UI center
	var local_hand_pos = to_local(grabbed_by.global_transform.origin)
	
	# We calculate the angle on the XZ plane (top-down view of the UI)
	# atan2 returns the angle in radians
	return atan2(local_hand_pos.x, local_hand_pos.z)
