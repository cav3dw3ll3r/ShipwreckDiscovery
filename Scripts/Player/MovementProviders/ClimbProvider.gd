@tool
extends XRToolsMovementProvider
class_name ClimbProvider

## Movement provider order
@export var order : int = 5

@onready var xrCamera = $"../../XRCamera3D"
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _controller := XRHelpers.get_xr_controller(self)

@export var _hand:XRToolsHand
var oldPos = Vector3.ZERO

func _ready() -> void:
	super()
	oldPos=_hand.global_position
	pass

# Add support for is_xr_class on XRTools classes
func is_xr_class(name : String) -> bool:
	return name == "XRToolsBuoyancy" or super(name)

func physics_movement(delta, playerBody, _disabled):
	var climbMove = _hand.global_position-oldPos
	# Clamping vertical velocity to prevent too extreme movements
	playerBody.velocity = climbMove
	oldPos = _hand.global_position
	return false
