extends Node3D
class_name Equipment_Holder

@onready var game_settings: GameSettings = get_tree().get_first_node_in_group("GameSettings")

@export var amateur_equipment_scene: PackedScene
@export var professional_equipment_scene: PackedScene
@export var binding: String = "ax_button"
## Scene default: spawn on left pickup when false means right. [member GameSettings.switch_hands] inverts at runtime.
@export var off_hand: bool = true
## Scene default: read [member binding] from left controller when true. [member GameSettings.switch_hands] inverts at runtime.
@export var binding_off_hand: bool = true
## [Node3D]s and [CanvasItem]s hidden while [member equipment_instance] is out; restored when it is returned (freed).
@export var invisible_while_equipped: Array[Node] = []

var equipment_instance: Node3D = null

var _pickup: XRToolsFunctionPickup
var _binding_controller: XRController3D
var _binding_connected: bool = false
var _base_off_hand: bool
var _base_binding_off_hand: bool


func _ready() -> void:
	add_to_group("EquipmentHolder")
	_base_off_hand = off_hand
	_base_binding_off_hand = binding_off_hand
	if game_settings and not game_settings.on_settings_update.is_connected(apply_hand_settings):
		game_settings.on_settings_update.connect(apply_hand_settings)
	apply_hand_settings()
	_sync_invisible_while_equipped_nodes()


func _exit_tree() -> void:
	if game_settings and game_settings.on_settings_update.is_connected(apply_hand_settings):
		game_settings.on_settings_update.disconnect(apply_hand_settings)


func _effective_off_hand() -> bool:
	if game_settings and game_settings.switch_hands:
		return not _base_off_hand
	return _base_off_hand


func _effective_binding_off_hand() -> bool:
	if game_settings and game_settings.switch_hands:
		return not _base_binding_off_hand
	return _base_binding_off_hand


## Rebind holster hand/controller when settings change (e.g. switch_hands). Clears active equipment.
func apply_hand_settings() -> void:
	if _binding_connected and is_instance_valid(_binding_controller):
		if _binding_controller.button_pressed.is_connected(_on_controller_button_pressed):
			_binding_controller.button_pressed.disconnect(_on_controller_button_pressed)
	_binding_connected = false
	if is_instance_valid(equipment_instance):
		_ensure_xr_handles()
		_destroy_equipment()
	_pickup = null
	_binding_controller = null


## Called before scene travel so teardown matches the in-world holster path (drop, cleanup, free).
func clear_equipped_for_travel() -> void:
	if is_instance_valid(equipment_instance):
		_ensure_xr_handles()
	_destroy_equipment()


func _sync_invisible_while_equipped_nodes() -> void:
	var show_rack := not is_instance_valid(equipment_instance)
	for n in invisible_while_equipped:
		if not is_instance_valid(n):
			continue
		if n is Node3D:
			(n as Node3D).visible = show_rack
		elif n is CanvasItem:
			(n as CanvasItem).visible = show_rack


func _physics_process(_delta: float) -> void:
	if _binding_connected:
		return
	if not _ensure_xr_handles():
		return
	if not _binding_controller.button_pressed.is_connected(_on_controller_button_pressed):
		_binding_controller.button_pressed.connect(_on_controller_button_pressed)
	_binding_connected = true


func _ensure_xr_handles() -> bool:
	var xr_camera := get_tree().get_first_node_in_group("Player")
	if xr_camera == null:
		return false
	var origin := xr_camera.get_parent()
	if origin == null:
		return false
	var use_off_hand := _effective_off_hand()
	var use_binding_off_hand := _effective_binding_off_hand()
	_pickup = XRToolsFunctionPickup.find_left(origin) if use_off_hand else XRToolsFunctionPickup.find_right(origin)
	if not is_instance_valid(_pickup):
		return false
	var binding_pickup := (
		XRToolsFunctionPickup.find_left(origin)
		if use_binding_off_hand
		else XRToolsFunctionPickup.find_right(origin)
	)
	if not is_instance_valid(binding_pickup):
		return false
	_binding_controller = binding_pickup.get_controller()
	return is_instance_valid(_binding_controller)


func _on_controller_button_pressed(p_button: Variant) -> void:
	if StringName(p_button) != StringName(binding):
		return
	if is_instance_valid(equipment_instance):
		_destroy_equipment()
	else:
		_spawn_equipment_into_hand()


func _active_equipment_scene() -> PackedScene:
	if game_settings and game_settings.amateur_mode:
		return amateur_equipment_scene
	return professional_equipment_scene


func _unequip_other_holders() -> void:
	for n in get_tree().get_nodes_in_group("EquipmentHolder"):
		if n == self or not (n is Equipment_Holder):
			continue
		var other := n as Equipment_Holder
		if is_instance_valid(other.equipment_instance):
			other._destroy_equipment()


func _spawn_equipment_into_hand() -> void:
	var scene := _active_equipment_scene()
	if scene == null or not is_instance_valid(_pickup):
		return
	_unequip_other_holders()
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(inst)
	else:
		add_child(inst)
	inst.global_transform = _pickup.global_transform
	equipment_instance = inst as XRToolsPickable
	_pickup._pick_up_object(inst)
	_sync_invisible_while_equipped_nodes()


func _destroy_equipment() -> void:
	if not is_instance_valid(equipment_instance):
		equipment_instance = null
		_sync_invisible_while_equipped_nodes()
		return
	var pickable := equipment_instance as XRToolsPickable
	# Exit equipment states before drop so let_go is not blocked (hand visibility).
	if equipment_instance is RevisedSpearPickable:
		(equipment_instance as RevisedSpearPickable).cleanup_before_unequip()
	elif equipment_instance is AmateurSpearPickable:
		(equipment_instance as AmateurSpearPickable).cleanup_before_unequip()
	elif equipment_instance is SeaScooterPickable:
		(equipment_instance as SeaScooterPickable).cleanup_before_unequip()
	elif equipment_instance is ProSeaScooterPickable:
		(equipment_instance as ProSeaScooterPickable).cleanup_before_unequip()
	elif equipment_instance is ZookeeperPickable:
		(equipment_instance as ZookeeperPickable).cleanup_before_unequip()
	elif is_instance_valid(_pickup) and _pickup.picked_up_object == equipment_instance:
		_pickup.drop_object()
	# Fallback when a blocked drop left grab driver active but pickup ref stale.
	if pickable != null and pickable.is_picked_up():
		var holder := pickable.get_picked_up_by()
		if is_instance_valid(holder):
			pickable.let_go(holder, Vector3.ZERO, Vector3.ZERO)
	if is_instance_valid(equipment_instance):
		equipment_instance.queue_free()
	equipment_instance = null
	_sync_invisible_while_equipped_nodes()
