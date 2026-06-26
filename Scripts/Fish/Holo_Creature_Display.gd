extends Node3D

class_name HologramCreatureDisplay

@export var min_distance:float = 0.5
@export var max_distance:float = 1.5

@onready var target: Node3D = get_tree().get_first_node_in_group("Player")

func set_anim_progress(progress):
	var mat:ShaderMaterial = $Area3D/Body.get_active_material(0)
	mat.set_shader_parameter("progress",progress)
	mat = $Holo_Backboard.get_active_material(0)
	mat.set_shader_parameter("progress",progress)

func set_scannable_data(scannable:Scannable):
	pass

func _process(delta):
	if not target:
		return

	var my_position = global_transform.origin
	var target_position = target.global_transform.origin

	# Only rotate around Y axis
	var direction = target_position - my_position
	#direction.y = 0

	if direction.length_squared() == 0:
		return # Avoid division by zero

	direction = direction.normalized()

	# Build right and up vectors
	var right = Vector3.UP.cross(direction).normalized()
	var up = Vector3.UP
	var forward = direction

	# Now build the Basis manually
	var basis = Basis()
	basis.x = right
	basis.y = up
	basis.z = forward

	global_transform.basis = basis.orthonormalized()
	# Linearly follow player's global Z AFTER rotation
	global_position.y = lerp(global_position.y,target.global_position.y,delta)
		# Constrain distance to 1–5 meters on XZ plane
	var offset = global_position - target.global_position
	offset.y = 0

	var dist = offset.length()
	if dist < min_distance:
		offset = offset.normalized() * min_distance
	elif dist > max_distance:
		offset = offset.normalized() * max_distance

	global_position.x = target.global_position.x + offset.x
	global_position.z = target.global_position.z + offset.z
