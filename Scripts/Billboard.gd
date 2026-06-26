extends Node3D

var target: Node3D

func _ready():
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		target = players[0]
	else:
		push_error("No player found in 'Player' group.")

func _process(delta):
	if not target:
		return

	var my_position = global_transform.origin
	var target_position = target.global_transform.origin

	# Only rotate around Y axis
	var direction = target_position - my_position
	direction.y = 0

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
