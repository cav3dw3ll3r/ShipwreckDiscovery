extends Node3D
class_name HandPoser

enum HandSide { LEFT, RIGHT }
@export var hand_side: HandSide = HandSide.RIGHT

@export var handIdle:MeshInstance3D
@export var handGrip:MeshInstance3D
@export var handPoint:MeshInstance3D
@export var pointNearOtherHand: Node3D

@onready var _controller := XRHelpers.get_xr_controller(self)
@onready var clickSound = preload("res://Prefabs/ClickSoundPlayer.tscn")
@onready var testMaterial = preload("res://Images/MeshTextures/GloveFull/Olive_Glove.tres")

var gripAction = "grip"
var isPointing = false # Now STRICTLY tracks if hovering an XRTools menu
var is_forced_pointing = false

enum poseStates {
	IDLE,
	GRIP,
	POINT
}

var poseState: poseStates = poseStates.IDLE
var game_settings

func _ready() -> void:
	if hand_side == HandSide.RIGHT:
		add_to_group("right_hand")
	else:
		add_to_group("left_hand")
		
	set_idle()

func _process(delta: float) -> void:
	if is_forced_pointing:
		return 
		
	var pressing_grip = _controller.is_button_pressed(gripAction)

	# A robust state machine that constantly evaluates the true hardware/UI state
	if pressing_grip and poseState != poseStates.GRIP:
		set_grip()
	elif not pressing_grip:
		if isPointing and poseState != poseStates.POINT:
			set_point()
		elif not isPointing and poseState != poseStates.IDLE:
			set_idle()

func force_point(active: bool) -> void:
	is_forced_pointing = active
	if active:
		set_point()
	else:
		# Immediately evaluate hardware/UI reality when the watch drops the override
		if _controller.is_button_pressed(gripAction):
			set_grip()
		elif isPointing:
			set_point()
		else:
			set_idle()

func clearHands():
	handIdle.visible = false
	handGrip.visible = false
	handPoint.visible = false

func point_event(event:Variant):
	if event != null:
		if event.event_type == XRToolsPointerEvent.Type.ENTERED:
			isPointing = true # ONLY mark UI hover state
		if event.event_type == XRToolsPointerEvent.Type.EXITED:
			isPointing = false # ONLY mark UI hover state
		if event.event_type == XRToolsPointerEvent.Type.RELEASED:
			add_child(clickSound.instantiate())
			_controller.trigger_haptic_pulse("haptic",0.0,0.15,0.1,0.0)

# The setters below now ONLY handle visuals and visual state records.
func set_idle():
	clearHands()
	handIdle.visible = true
	poseState = poseStates.IDLE

func set_grip():
	clearHands()
	handGrip.visible = true
	poseState = poseStates.GRIP

func set_point():
	clearHands()
	handPoint.visible = true
	poseState = poseStates.POINT

func skin_hand(material:StandardMaterial3D):
	handGrip.set_surface_override_material(0,material)
	handIdle.set_surface_override_material(0,material)
	handPoint.set_surface_override_material(0,material)
