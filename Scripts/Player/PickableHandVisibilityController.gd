extends Node
class_name PickableHandVisibilityController

## The high-fidelity rig hand models that should be hidden when holding equipment.
@export var left_hand_visual: Node3D
@export var right_hand_visual: Node3D

var _left_hidden_by_pickable := false
var _right_hidden_by_pickable := false

var _defer_restore_left := false
var _defer_restore_right := false

func _ready() -> void:
	_defer_restore_left = false
	_defer_restore_right = false
	_set_left_hidden(false)
	_set_right_hidden(false)

func _exit_tree() -> void:
	_defer_restore_left = false
	_defer_restore_right = false
	_set_left_hidden(false)
	_set_right_hidden(false)

func on_left_picked_up(what: Variant) -> void:
	if _is_pickable_not_climbable(what):
		# Hide rig hand immediately for wizard equipment
		_defer_restore_left = (what is RevisedSpearPickable or what is AmateurSpearPickable or what is SeaScooterPickable or what is ProSeaScooterPickable or what is ZookeeperPickable)
		_set_left_hidden(true)

func on_left_dropped() -> void:
	if _defer_restore_left:
		call_deferred("_resolve_deferred_drop_restore", true)
		return
	_defer_restore_left = false
	_set_left_hidden(false)

func on_right_picked_up(what: Variant) -> void:
	if _is_pickable_not_climbable(what):
		_defer_restore_right = (what is RevisedSpearPickable or what is AmateurSpearPickable or what is SeaScooterPickable or what is ProSeaScooterPickable or what is ZookeeperPickable)
		_set_right_hidden(true)

func on_right_dropped() -> void:
	if _defer_restore_right:
		call_deferred("_resolve_deferred_drop_restore", false)
		return
	_defer_restore_right = false
	_set_right_hidden(false)

func release_left_pickable_hand_visibility_lock() -> void:
	_defer_restore_left = false
	_set_left_hidden(false)

func release_right_pickable_hand_visibility_lock() -> void:
	_defer_restore_right = false
	_set_right_hidden(false)

func _set_left_hidden(hidden: bool) -> void:
	_left_hidden_by_pickable = hidden
	if is_instance_valid(left_hand_visual):
		left_hand_visual.visible = not hidden

func _set_right_hidden(hidden: bool) -> void:
	_right_hidden_by_pickable = hidden
	if is_instance_valid(right_hand_visual):
		right_hand_visual.visible = not hidden

func _is_pickable_not_climbable(what: Variant) -> bool:
	if not is_instance_valid(what):
		return false
	if what is XRToolsClimbable:
		return false
	return what is XRToolsPickable

func _resolve_deferred_drop_restore(is_left_hand: bool) -> void:
	# General lock check: If the hand is holding a spear or zookeeper, it stays hidden.
	var spear_locked = _is_hand_holding_spear(is_left_hand)
	var scooter_locked = _is_hand_holding_scooter(is_left_hand)
	var zookeeper_locked = _is_hand_holding_zookeeper(is_left_hand)

	if spear_locked or scooter_locked or zookeeper_locked:
		return

	if is_left_hand:
		_defer_restore_left = false
		_set_left_hidden(false)
	else:
		_defer_restore_right = false
		_set_right_hidden(false)

# --- Equipment Detection Helpers ---

## Checks if the specific hand is holding the spear in any valid state.
func _is_hand_holding_spear(is_left_hand: bool) -> bool:
	var expected_tracker := &"left_hand" if is_left_hand else &"right_hand"
	var scene := get_tree().current_scene
	if not is_instance_valid(scene): return false
	
	var nodes := scene.find_children("*", "RevisedSpearPickable", true, false)
	for node in nodes:
		var spear = node as RevisedSpearPickable
		if is_instance_valid(spear) and spear.is_picked_up():
			var pickup = spear.get_picked_up_by()
			if is_instance_valid(pickup):
				var controller = XRHelpers.get_xr_controller(pickup)
				if controller and controller.tracker == expected_tracker:
					return true

			if spear._grab_driver and spear._grab_driver.secondary:
				var s_pickup = spear._grab_driver.secondary.by
				var s_controller = XRHelpers.get_xr_controller(s_pickup)
				if s_controller and s_controller.tracker == expected_tracker:
					return true

	var amateur_nodes := scene.find_children("*", "AmateurSpearPickable", true, false)
	for node in amateur_nodes:
		var amateur_spear = node as AmateurSpearPickable
		if is_instance_valid(amateur_spear) and amateur_spear.is_picked_up():
			var pickup = amateur_spear.get_picked_up_by()
			if is_instance_valid(pickup):
				var controller = XRHelpers.get_xr_controller(pickup)
				if controller and controller.tracker == expected_tracker:
					return true
	return false

## Checks if the specific hand is holding a sea scooter in any valid state.
func _is_hand_holding_scooter(is_left_hand: bool) -> bool:
	var expected_tracker := &"left_hand" if is_left_hand else &"right_hand"
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return false

	var nodes := scene.find_children("*", "SeaScooterPickable", true, false)
	for node in nodes:
		var scooter = node as SeaScooterPickable
		if is_instance_valid(scooter) and scooter.is_picked_up():
			var pickup = scooter.get_picked_up_by()
			if is_instance_valid(pickup):
				var controller = XRHelpers.get_xr_controller(pickup)
				if controller and controller.tracker == expected_tracker:
					return true
	var pro_nodes := scene.find_children("*", "ProSeaScooterPickable", true, false)
	for node in pro_nodes:
		var pro_scooter = node as ProSeaScooterPickable
		if is_instance_valid(pro_scooter) and pro_scooter.is_picked_up():
			var pickup = pro_scooter.get_picked_up_by()
			if is_instance_valid(pickup):
				var controller = XRHelpers.get_xr_controller(pickup)
				if controller and controller.tracker == expected_tracker:
					return true
	return false

## Checks if the specific hand is holding a zookeeper.
func _is_hand_holding_zookeeper(is_left_hand: bool) -> bool:
	var expected_tracker := &"left_hand" if is_left_hand else &"right_hand"
	var scene := get_tree().current_scene
	if not is_instance_valid(scene): return false
	
	var nodes := scene.find_children("*", "ZookeeperPickable", true, false)
	for node in nodes:
		var zk = node as XRToolsPickable # Cast to base to use RTFM functions
		if is_instance_valid(zk) and zk.is_picked_up():
			var pickup = zk.get_picked_up_by()
			if is_instance_valid(pickup):
				var controller = XRHelpers.get_xr_controller(pickup)
				if controller and controller.tracker == expected_tracker:
					return true
	return false
