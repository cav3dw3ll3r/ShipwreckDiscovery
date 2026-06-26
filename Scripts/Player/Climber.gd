extends Area3D
class_name Climber

# Export variables
@export var handVisual: Node3D
@export var inputAction: String = "grip"

# Signals
signal on_grab(grabHand)
signal on_let_go()

# External Data
var _controller:XRController3D

# Local Properties
var canGrab: bool = false
var isGrabbing: bool = false
var targetGrabbable: Node3D
var handGrabPos: Vector3
var grabHandPrefab = preload("res://Prefabs/grab_hand.tscn")
var grabHand

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_controller = XRTools.find_xr_ancestor(self, "*", "XRController3D")
	pass # Replace with function body.

# Called when the area detects a grapple target (collision layer 5)
func _on_area_body_entered(body):
	if(!isGrabbing):
		targetGrabbable = body
	canGrab = true

func _on_area_body_exited(body):
	if(body == targetGrabbable):
		canGrab = false

func grab():
	isGrabbing=true
	grabHand = grabHandPrefab.instantiate()
	targetGrabbable.add_child(grabHand)
	grabHand.global_position = global_position
	if(handVisual): handVisual.visible=false
	on_grab.emit(targetGrabbable)
	pass

func let_go():
	isGrabbing=false
	grabHand.queue_free()
	grabHand=null
	if(handVisual): handVisual.visible=true
	on_let_go.emit()
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do something different if the player has already grabbed
	if(isGrabbing):
		if(_controller.get_float(inputAction)<=0.8):
			let_go()
	else:
		if(_controller.get_float(inputAction)>=0.8 and canGrab and targetGrabbable):
			grab()
	pass
