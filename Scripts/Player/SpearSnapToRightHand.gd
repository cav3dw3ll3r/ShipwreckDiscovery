extends Node
class_name SpearSnapToRightHand

@export var snap_action: StringName = &"by_button"
@export var snap_haptic_action: StringName = &"haptic"
@export var snap_haptic_amplitude: float = 0.2
@export var snap_haptic_duration: float = 0.05

@onready var _controller := XRHelpers.get_xr_controller(self)
@onready var _pickup := XRToolsFunctionPickup.find_right(self)

var _was_pressed: bool = false


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_controller):
		_controller = XRHelpers.get_xr_controller(self)
	if not is_instance_valid(_pickup):
		_pickup = XRToolsFunctionPickup.find_right(self)
	if not _controller or not _pickup:
		return

	var is_pressed: bool = _controller.is_button_pressed(snap_action)
	if is_pressed and not _was_pressed:
		_snap_spear()
	_was_pressed = is_pressed


func _snap_spear() -> void:
	var spear: Node3D = _resolve_spear()
	if not is_instance_valid(spear):
		return
	if _pickup.picked_up_object == spear:
		return
	if spear.has_method("can_pick_up") and not spear.can_pick_up(_pickup):
		return
	_pickup.call("_pick_up_object", spear)
	if _pickup.picked_up_object == spear:
		_controller.trigger_haptic_pulse(snap_haptic_action, 0.0, snap_haptic_amplitude, snap_haptic_duration, 0.0)


func _resolve_spear() -> Node3D:
	return get_tree().get_first_node_in_group("Projectile") as Node3D
