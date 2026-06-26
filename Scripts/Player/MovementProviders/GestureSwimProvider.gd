@tool
extends XRToolsMovementProvider
class_name GestureSwimProvider

## Movement provider order
@export var order : int = 5

@onready var xrCamera = get_tree().get_first_node_in_group("Player")
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Controller node
@onready var left_controller := XRHelpers.get_left_controller(self)
@onready var right_controller := XRHelpers.get_right_controller(self)

var left_relative_positions = []
var right_relative_positions = []
var relative_times = []

const b_button = "by_button"

func _ready() -> void:
	super()

func is_xr_class(name : String) -> bool:
	return name == "XRToolsDepth" or super(name)

func log_velocity_entry(position_array:Array,time_array:Array,position_data,delta):
	var shave_time = 0
	if(len(position_array)<10):
		position_array.append(position_data)
		time_array.append(delta)
		
	else:
		position_array.pop_front()
		time_array.pop_front()
	
	shave_time = time_array[0]
	
	for i in range(len(time_array)):
		time_array[i]-=shave_time

func calculate_average_hand_velocities() -> Array:
	var left_avg_vel = Vector3.ZERO
	var right_avg_vel = Vector3.ZERO

	left_avg_vel = _calculate_avg_velocity_from_logs(left_relative_positions, relative_times)
	right_avg_vel = _calculate_avg_velocity_from_logs(right_relative_positions, relative_times)
	
	return [
		left_avg_vel,
		right_avg_vel
	]

func _calculate_avg_velocity_from_logs(position_array: Array, time_array: Array) -> Vector3:
	if len(position_array) < 2 or len(time_array) < 1:
		return Vector3.ZERO

	var total_velocity = Vector3.ZERO
	var total_time = 0.0

	for i in range(1, len(position_array)):
		var delta_pos = position_array[i] - position_array[i - 1]
		var delta_time = time_array[i - 1]
		if delta_time > 0:
			var velocity = delta_pos / delta_time
			total_velocity += velocity * delta_time
			total_time += delta_time

	if total_time > 0:
		return total_velocity / total_time
	else:
		return Vector3.ZERO

func get_hand_velocity(delta,playerBody):
	log_velocity_entry(
		right_relative_positions,
		relative_times,
		right_controller.position,
		delta)
	log_velocity_entry(
		left_relative_positions,
		relative_times,
		left_controller.position,
		delta)
	
	if len(left_relative_positions)<10 or len(right_relative_positions)<10:
		return [Vector3.ZERO,Vector3.ZERO]
	else:
		return calculate_average_hand_velocities()

func physics_movement(delta, playerBody, _disabled):
	# Early out
	if not right_controller.is_button_pressed(b_button): return false

	# Track hand velocity only as they swing around the player by subtracting
	# the player's body velocity

	var speeds = get_hand_velocity(delta,playerBody)
	var left_speed_relative = speeds[0]
	var right_speed_relative = speeds[1]
	# Check the orientation of each hand as well
	var left_palm_facing = left_controller.global_transform.basis.x
	var right_palm_facing = -1*right_controller.global_transform.basis.x
	
	return false

func calculate_push_vector(left_palm_facing: Vector3, right_palm_facing: Vector3, left_speed_relative: float, right_speed_relative: float) -> Vector3:
	# Normalize inputs just in case
	var left_dir = left_palm_facing.normalized()
	var right_dir = right_palm_facing.normalized()

	# Flip right palm facing to align direction with left hand
	var right_dir_flipped = -right_dir

	# Weighted sum of directions based on speeds
	var total_speed = left_speed_relative + right_speed_relative
	if total_speed < 0.0001:
		return Vector3.ZERO  # Avoid division by zero

	var avg_dir = (left_dir * left_speed_relative + right_dir_flipped * right_speed_relative) / total_speed

	# Normalize avg direction and scale by average speed
	var avg_speed = total_speed * 0.5

	return avg_dir.normalized() * avg_speed
