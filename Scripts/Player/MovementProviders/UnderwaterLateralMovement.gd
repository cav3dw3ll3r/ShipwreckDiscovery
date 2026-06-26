extends XRToolsMovementProvider
class_name LateralSwimProvider

@onready var _controller := XRHelpers.get_xr_controller(self)
@export var speed: float = 5.

var order = 50
var camera: XRCamera3D

func _ready():
	# Standard way to find the camera in XRTools if groups aren't reliable:
	# camera = XRHelpers.get_right_hand(self).get_viewport().get_camera_3d()
	camera = get_tree().get_first_node_in_group("Player")

func physics_movement(delta: float, player_body: XRToolsPlayerBody, _disabled: bool):
	if _disabled or !_controller:
		return

	var input = XRToolsUserSettings.get_adjusted_vector2(_controller, "primary")
	
	if input != Vector2.ZERO:
		# 1. Get the camera direction vectors
		var cam_basis = camera.global_transform.basis
		
		# 2. Flatten vectors to the XZ plane (set Y to 0)
		var forward = Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
		var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
		
		# 3. Calculate movement direction based on input
		# input.x is strafe, input.y is forward/back
		# Note: In Godot, -Z is forward, but Basis.z points backward, 
		# so we use -input.y to move in the direction we are looking.
		var direction = (forward * -input.y) + (right * input.x)
		
		# 4. Apply velocity
		# Using move_and_slide style velocity addition
		player_body.velocity += direction * speed * delta
