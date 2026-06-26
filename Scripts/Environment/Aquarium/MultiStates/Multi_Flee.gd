extends MultiState
class_name MultiFlee

static func update(i: int, delta: float, controller: MultiFishController):
	var player_pos = controller.player.global_position
	var fish_pos = controller.positions[i]
	var dist = fish_pos.distance_to(player_pos)
	
	# Safety check to avoid division by zero
	if dist < 0.001: dist = 0.001

	var away_dir = (fish_pos - player_pos).normalized()
	
	# 1. SET THE TARGET INTENT (No Lerp)
	# We scale the speed so they swim faster when the player is closer, 
	# but we keep it within a reasonable 'panic' range.
	var flee_speed_mult = clamp(controller.flee_distance / dist, 1.0, 2.5)
	controller.velocities[i] = away_dir * (controller.swim_speed * flee_speed_mult)

	# 2. STATE TRANSITION
	# If the fish is successfully pointing away AND is at a safe distance, 
	# go back to wandering.
	if controller.velocities[i].normalized().dot(away_dir) >= 0.85 and dist > controller.flee_distance:
		controller.current_states[i] = controller.FISH_DIRECTIVE.WANDER
