extends State

var total_turn_amount
var amount_turned = 0
var turn_speed = 0.5

func enter(stateMachine):
	super(stateMachine)
	total_turn_amount = randf_range(-180.0,180.0)
	turn_speed = turn_speed/stateMachine.forward_swim_speed

func update(delta):
	var fwd_amount = stateMachine.forward_swim_speed
	if "fish_racer" in stateMachine.game_settings.active_powers:
		fwd_amount = (fwd_amount+5)*1.5
	if stateMachine.is_sunfish and "sunfish_pilot" in stateMachine.game_settings.active_powers:
		fwd_amount *= 4
	# Move forward in world space
	stateMachine.global_position += -stateMachine.global_transform.basis.z * delta * fwd_amount

	# Get the first player node
	var player = stateMachine.get_tree().get_nodes_in_group("Player").front()
	if player == null:
		return

	# --- ROTATION (YAW) ---

	# Get horizontal (XZ) forward direction from both objects
	var target_forward = -player.global_transform.basis.z
	target_forward.y = 0
	target_forward = target_forward.normalized()

	var current_forward = -stateMachine.global_transform.basis.z
	current_forward.y = 0
	current_forward = current_forward.normalized()

	# Angle and turn direction
	var angle_yaw = acos(clamp(current_forward.dot(target_forward), -1.0, 1.0))
	var cross_yaw = current_forward.cross(target_forward).y
	var yaw_direction = sign(cross_yaw)

	# Apply smooth yaw
	var max_yaw = delta * turn_speed
	var yaw_amount = min(angle_yaw, max_yaw) * yaw_direction
	stateMachine.global_rotate(Vector3.UP, yaw_amount)

	# --- TILT (PITCH) ---

	# Get full forward vectors (normalized)
	var player_forward = -player.global_transform.basis.z.normalized()
	var current_forward_full = -stateMachine.global_transform.basis.z.normalized()

	# Get elevation angle from forward vector using asin(y)
	var target_pitch = asin(clamp(player_forward.y, -1.0, 1.0))
	var current_pitch = asin(clamp(current_forward_full.y, -1.0, 1.0))

	# Clamp target pitch between -30 and 30 degrees
	var min_pitch = deg_to_rad(-30)
	var max_pitch = deg_to_rad(30)
	if stateMachine.global_position.y >= -5.0:
		max_pitch = deg_to_rad(0)
	if stateMachine.is_sunfish and "sunfish_pilot" in stateMachine.game_settings.active_powers:
		max_pitch = deg_to_rad(80)
		min_pitch = deg_to_rad(-80)

	target_pitch = clamp(target_pitch, min_pitch, max_pitch)

	# Interpolate pitch
	var pitch_delta = target_pitch - current_pitch
	var max_pitch_step = delta * turn_speed  # Reuse same speed for simplicity
	pitch_delta = clamp(pitch_delta, -max_pitch_step, max_pitch_step)

	# Pitch axis is local X axis in world space
	var pitch_axis = stateMachine.global_transform.basis.x.normalized()
	stateMachine.global_rotate(pitch_axis, pitch_delta)
