extends Control

@onready var scanner_display: ScannerDisplay = $ScannerDisplay
@onready var scan_point: Node3D = get_tree().get_first_node_in_group("Scanner")
@onready var main_menu: MainMenuTabs = get_tree().get_first_node_in_group("MainMenu")
@onready var player_camera = get_tree().get_first_node_in_group("Player")

@export var hologram_spawn_distance: float = 1.75

var scan_details_menu = preload("res://Prefabs/UI/WatchSubMenus/scan_details_menu.tscn")
var main_watch_menu = preload("res://Prefabs/UI/WatchSubMenus/top_level_menu.tscn")


func _ready() -> void:
	scanner_display.scan_completed.connect(_on_scan_completed)


func _on_scan_completed(target: Spotlight_Target, world_pos: Vector3) -> void:
	complete_scan(target, world_pos)


func back() -> void:
	var main_inst = main_watch_menu.instantiate()
	get_parent().add_child(main_inst)
	queue_free()


func complete_scan(spotlight_target: Spotlight_Target, _target_world_pos: Vector3) -> void:
	var currently_scanning = spotlight_target.scannable
	if currently_scanning.scannable_type == currently_scanning.ScanType.SUPPORTER:
		main_menu.open_context_menu(currently_scanning.scan_prefab)
		return
	elif currently_scanning.scannable_type == currently_scanning.ScanType.CREATURE:
		var scan_details_instance: Scan_Details = scan_details_menu.instantiate()
		scan_details_instance.scannable = currently_scanning
		scan_details_instance.hologram = spotlight_target.scanner_hologram.instantiate()
		scan_details_instance.hologram.global_position = get_hologram_spawn_position()
		get_tree().root.add_child(scan_details_instance.hologram)
		get_parent().add_child(scan_details_instance)
		queue_free()


func get_hologram_spawn_position() -> Vector3:
	var view_camera: Camera3D = null
	if player_camera is Camera3D:
		view_camera = player_camera
	elif player_camera and player_camera.has_method("get_node_or_null"):
		view_camera = player_camera.get_node_or_null("Camera3D")

	if view_camera:
		var forward = -view_camera.global_transform.basis.z.normalized()
		return view_camera.global_position + (forward * hologram_spawn_distance)

	if scan_point:
		var fallback_forward = -scan_point.global_transform.basis.z.normalized()
		return scan_point.global_position + (fallback_forward * hologram_spawn_distance)
	return Vector3.ZERO
