@tool
extends XRToolsMovementProvider
class_name DepthControlProvider

## Movement provider order
@export var order : int = 5

## Input action for movement direction
@export var input_action : String = "primary"

@onready var xrCamera = $"../../XRCamera3D"
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Controller node
@onready var _controller := XRHelpers.get_xr_controller(self)

var waves
var heightOffset=-0.1
var submerged = false
var waterDrag = 0.2


func getWaterHeight(x:float, z:float) -> float:
	return waves.getWaveHeight(x,z)

func _ready() -> void:
	super()
	# Get the only waves in the tree
	waves = get_tree().get_first_node_in_group("Waves")
	pass

# Add support for is_xr_class on XRTools classes
func is_xr_class(name : String) -> bool:
	return name == "XRToolsDepth" or super(name)

func physics_movement(delta, playerBody, _disabled):
	if not waves: return
	var depth = waves.getWaveHeight(xrCamera.global_position.x,xrCamera.global_position.z)-(xrCamera.global_position.y+heightOffset)
	var dz_input_action = XRToolsUserSettings.get_adjusted_vector2(_controller, input_action)
	if(depth>0):
		## get input action with deadzone correction applied
		playerBody.velocity.y += dz_input_action.y*delta*3.0
		pass
	elif(dz_input_action.y<0):
		playerBody.velocity.y += dz_input_action.y*delta*3.0
		pass
	# Slow the player down
	playerBody.velocity = lerp(playerBody.velocity,Vector3.ZERO,delta*4.0)
	
	#TODO: Reimplement using lerp after waves has push force again
	#var force_depth = clamp(depth,0,100)
	#playerBody.velocity += Vector3(waves.push_force.x*(1-(force_depth/100))*delta,0.0,waves.push_force.y*(1-(force_depth/100))*delta)
	
	return false
