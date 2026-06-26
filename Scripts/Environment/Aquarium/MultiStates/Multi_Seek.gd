extends MultiState
class_name MultiSeek

static func update(i: int, delta: float, controller: MultiFishController):
	var fish_pos = controller.positions[i]
	var center_pos = controller.school_center

	# 1. Calculate the clear target direction
	var seek_dir = (center_pos - fish_pos).normalized()

	# 2. SET THE RAW INTENT
	# We tell the controller: "I want to be going full speed toward the center."
	# The controller's turn_speed will handle the actual rotation.
	controller.velocities[i] = seek_dir * controller.swim_speed

	# 3. TRANSITION LOGIC
	# We check if we are successfully heading back toward the center 
	# AND if we are within a reasonable distance of the center again.
	var dist_to_center = fish_pos.distance_to(center_pos)
	
	# If we are facing the center and have moved back inside the swim_radius
	if controller.velocities[i].normalized().dot(seek_dir) >= 0.85 and dist_to_center < controller.swim_radius:
		controller.current_states[i] = controller.FISH_DIRECTIVE.WANDER
