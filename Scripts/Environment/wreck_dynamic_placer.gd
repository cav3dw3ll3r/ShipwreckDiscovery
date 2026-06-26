extends Node

@export_node_path("MultiMeshInstance3D") var lionfish_path: NodePath = ^"../Lionfish"
@export_node_path("MultiMeshInstance3D") var trash_path: NodePath = ^"../Trash"

@export var area_size: Vector2 = Vector2(40, 40)
@export var circumnavigate_radius: float = 25.0
@export var ray_height: float = 40.0
@export var max_distance: float = 160.0
@export var trash_count_multiplier: float = 50.0


func _ready() -> void:
	await get_tree().physics_frame
	_place_dynamic_content()


func _place_dynamic_content() -> void:
	var wreck_id := _resolve_wreck_id()
	if wreck_id.is_empty():
		push_warning("WreckDynamicPlacer: could not resolve wreck id.")
		_free_static_wreck_geometry()
		return

	var state := SessionManager.get_wreck_state(wreck_id)
	var placer := ShelteredScatterPlacer.new()
	placer.area_size = area_size
	placer.circumnavigate_radius = circumnavigate_radius
	placer.ray_height = ray_height
	placer.max_distance = max_distance

	var lionfish := get_node_or_null(lionfish_path)
	if lionfish and lionfish.has_method("populate_from_world_transforms"):
		placer.randomize_scale = true
		placer.scale_min = lionfish.scale_min
		placer.scale_max = lionfish.scale_max
		var lionfish_count: int = state.get("lionfish_present", 0)
		var lionfish_xforms := placer.scatter(get_tree(), lionfish_count)
		lionfish.populate_from_world_transforms(lionfish_xforms)

	var trash := get_node_or_null(trash_path)
	if trash and trash.has_method("populate_from_world_transforms"):
		placer.randomize_scale = false
		var trash_coverage: float = state.get("trash_coverage", 0.0)
		var trash_count := maxi(0, roundi(trash_coverage * trash_count_multiplier))
		var trash_xforms := placer.scatter(get_tree(), trash_count)
		trash.populate_from_world_transforms(trash_xforms)

	_free_static_wreck_geometry()


func _free_static_wreck_geometry() -> void:
	for node in get_tree().get_nodes_in_group("static_wreck_geometry"):
		if is_instance_valid(node):
			node.queue_free()


func _resolve_wreck_id() -> String:
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings == null or game_settings.current_level.is_empty():
		return ""
	var level_data := load(game_settings.current_level) as LevelData
	return level_data.nameID if level_data else ""
