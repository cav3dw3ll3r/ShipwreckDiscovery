@tool
extends XRToolsMovementProvider
class_name BuoyancyProvider

## Movement provider order
@export var order : int = 5

## Input action for movement direction
@export var input_action : String = "primary"

@onready var xrCamera = $"../../XRCamera3D"
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _controller := XRHelpers.get_xr_controller(self)

var waves:Waves

var floatForce = 2.5
var heightOffset=-0.2
var submerged = false
var waterDrag = 0.4


func getWaterHeight(x:float, z:float) -> float:
	return waves.getWaveHeight(x,z)

func _ready() -> void:
	super()
	# Get the only waves in the tree
	waves = get_tree().get_first_node_in_group("Waves")
	
	pass

# Add support for is_xr_class on XRTools classes
func is_xr_class(name : String) -> bool:
	return name == "XRToolsBuoyancy" or super(name)

func physics_movement(delta, playerBody, _disabled):
	if not waves: return
	var depth = waves.getWaveHeight(xrCamera.global_position.x, xrCamera.global_position.z) - (xrCamera.global_position.y + heightOffset)
	var dz_input_action = XRToolsUserSettings.get_adjusted_vector2(_controller, input_action)

	if(dz_input_action.y<0):
		return false
	# Check if the player is submerged
	if depth > 0:
		submerged = true
		# Apply buoyant force with gravity offset
		var buoyant_force = gravity * depth * floatForce
		playerBody.velocity += Vector3.UP * buoyant_force * delta
		
		# Smooth vertical velocity to make the player settle gradually
		playerBody.velocity.y = lerp(playerBody.velocity.y, 0.0, delta * 3.0)
	else:
		# Apply gravity if not submerged
		playerBody.velocity += Vector3.DOWN * gravity * delta
		# Apply a soft downward force when close to the water
		if depth > -0.3:
			playerBody.velocity.y = lerp(playerBody.velocity.y, 0.0, delta * 5.0)
	
	# Damping: Slow down vertical movement for settling, reducing unwanted bouncing
	# Adjusting damping factor based on distance from water level
	if abs(depth) < 0.1:
		playerBody.velocity.y = lerp(playerBody.velocity.y, 0.0, delta * 10.0)  # Fast settling near surface
	
	# Clamping vertical velocity to prevent too extreme movements
	playerBody.velocity.y = clamp(playerBody.velocity.y, -35.0, 10.0)

	playerBody.velocity += Vector3(waves.push_force.x*delta,0.0,waves.push_force.y*delta)
	return false
