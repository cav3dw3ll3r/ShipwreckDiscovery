extends MOBehavior

class_name TargetDepthBehavior

@export var target_depth_min = -10.0
@export var target_depth_max = -5.0
var wave_control:Waves
var target_depth = 0.0

func start(owner:Node3D) -> void:
	wave_control = owner.get_tree().get_first_node_in_group("Waves")

func compute(owner:Node3D, delta:float) -> void:
	var depth = 0
	var wave_height = 0
	wave_control = owner.get_tree().get_first_node_in_group("Waves")
	if not wave_control:
		return 
	
	wave_height = wave_control.getWaveHeight(owner.global_position.x, owner.global_position.z)
	depth = wave_height-owner.global_position.y
	if depth<target_depth_min/2:
		owner.global_position.y = wave_height-target_depth_min/2
	if depth<target_depth_min:
		owner.global_position.y = lerpf(owner.global_position.y,wave_height-target_depth_min,delta*blend_factor)
	elif depth>target_depth_max:
		owner.global_position.y = lerpf(owner.global_position.y,wave_height-target_depth_max,delta*blend_factor)

func stop(owner:Node3D) -> void:
	pass
