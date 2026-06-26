extends MultiState
class_name MultiWander

const FISH_DIRECTIVE = preload("res://Scripts/Environment/Aquarium/Multi_State_Enums.gd").FISH_DIRECTIVE

static func update(i: int, delta: float, controller: MultiFishController):
	# 1. We use other_data_1 as a simple timer
	# We only want to pick a new 'vague' direction every so often
	controller.other_data_1[i] += delta
	
	# If we haven't picked a target yet, or it's time for a new one
	if controller.other_data_1[i] > 1.5: # Change 'noise' every 1.5s
		controller.other_data_1[i] = 0.0
		
		# Generate a 'Wander Force' - a random point on a sphere
		var wander_force = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.2, 0.2), # Keep vertical wandering subtle
			randf_range(-1.0, 1.0)
		).normalized() * 0.5 # The 'strength' of the curve
		
		# 2. Combine current velocity with the wander force
		# This creates a 'Target Velocity' that is slightly off-course
		var target_vel = (controller.velocities[i] + wander_force).normalized() * controller.swim_speed
		
		# 3. SET THE INTENT
		# We don't lerp here. We tell the controller 'This is the goal.'
		controller.velocities[i] = target_vel
		
	# 4. Occasionally, fish get a 'strong' urge to change direction entirely
	if randf() < 0.005: # Small chance per tick
		var new_heading = controller.velocities[i].rotated(Vector3.UP, randf_range(-PI/2, PI/2))
		controller.other_data_1[i] = new_heading.x
		controller.other_data_2[i] = new_heading.y
		controller.other_data_3[i] = new_heading.z
		controller.current_states[i] = FISH_DIRECTIVE.FOLLOW_HEADING
