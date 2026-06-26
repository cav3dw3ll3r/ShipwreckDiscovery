extends RigidBody3D

@export var float_force := 1.0
@export var water_drag := 0.05
@export var water_angular_drag := 0.05

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var water

var submerged := false

# Called when the node enters the scene tree for the first time.
func _ready():
	water = get_tree().get_nodes_in_group("Waves")[0]
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _physics_process(delta):
	submerged = false
	var depth = water.getWaveHeight(global_position.x,global_position.z) - global_position.y 
	if depth > 0:
		submerged = true
		apply_force(Vector3.UP * float_force * gravity * depth, global_position)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if submerged:
		state.linear_velocity *=  1 - water_drag
		state.angular_velocity *= 1 - water_angular_drag 
