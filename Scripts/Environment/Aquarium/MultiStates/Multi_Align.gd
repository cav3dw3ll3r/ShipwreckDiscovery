extends MultiState
class_name MultiAlign

static func update(i: int, delta: float, controller: MultiFishController):
	# 1. Reconstruct the target direction from the 'other_data' buffer
	var seek_dir = Vector3(
		controller.other_data_1[i],
		controller.other_data_2[i],
		controller.other_data_3[i]
	).normalized()

	# 2. SET THE INTENT (No Lerp)
	# We set the velocity to exactly what we want it to be.
	# The Controller's 'turn_speed' will handle the smooth transition to this.
	controller.velocities[i] = seek_dir * controller.swim_speed

	# 3. Check if we have arrived at this heading
	# Since the Controller is lerping, we check the CURRENT velocity 
	# against the SEEK direction to see if we've 'aligned' yet.
	if controller.velocities[i].normalized().dot(seek_dir) >= 0.95:
		# Reset buffer and go back to wandering
		controller.other_data_1[i] = 0.0
		controller.other_data_2[i] = 0.0
		controller.other_data_3[i] = 0.0
		controller.current_states[i] = controller.FISH_DIRECTIVE.WANDER
