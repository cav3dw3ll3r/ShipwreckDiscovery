@tool
extends XRToolsPickable

var user:XRToolsPlayerBody
var user_sm:PlayerStateMachine
#var controller:XRController3D

func _ready():
	# If this is missing, handles won't be registered!
	super() 
	connect("picked_up",_on_picked_up)
	connect("dropped",_on_let_go)

func _on_picked_up(by: Node):
	# 'by' is the FunctionPickup. 
	# We want the Origin first, then the Body.
	var xr_camera = get_tree().get_first_node_in_group("Player")
	var origin = xr_camera.get_parent()
	if origin:
		# Search the origin's children for the PlayerBody
		user = XRToolsPlayerBody.find_instance(origin)
		user_sm = user.get_node("../PlayerStateMachine")
	if not user:
		push_warning("Scooter: Could not find XRToolsPlayerBody!")
	else:
		pass

func _on_let_go():
	user = null
	
func _process(delta):
	if user:
		var controller = get_picked_up_by_controller()
		var input = XRToolsUserSettings.get_adjusted_vector2(controller,"primary")
		if input.y<0:
			user.velocity+=global_basis.y.normalized()*5.*delta*(-1.*input.y)
	pass
