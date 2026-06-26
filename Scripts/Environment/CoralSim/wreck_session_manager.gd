extends Node

@export_node_path("CoralMultiMeshController") var coral_controller_path: NodePath
@export var coral_controller_scene: PackedScene = preload("res://Prefabs/Environment/corals/coral_multimesh_parent.tscn")

var _active_wreck_id: String = ""
var _active_coral_controller: CoralMultiMeshController


func _ready() -> void:
	SignalBus.coral_planted.connect(_on_coral_world_changed)
	SignalBus.coral_damaged.connect(_on_coral_damaged)
	SessionManager.wreck_visuals_changed.connect(_on_wreck_visuals_changed)
	await get_tree().process_frame
	_begin_session()


func _begin_session() -> void:
	var wreck_id := _resolve_wreck_id()
	if wreck_id.is_empty():
		push_warning("WreckSessionManager: could not resolve wreck id.")
		return

	_active_wreck_id = wreck_id
	_apply_session_corals()
	_hook_aquarium_loader()


func _apply_session_corals() -> void:
	if _active_wreck_id.is_empty():
		return
	_refresh_coral(_active_wreck_id)


func _refresh_coral(wreck_id: String) -> void:
	var corals := SessionManager.get_corals_for_wreck(wreck_id)
	var controller := _find_coral_controller()
	if controller == null:
		return
	controller.refresh_from_session(corals)


func _on_coral_world_changed(_type: CoralData.CoralType, _global_pos: Vector3) -> void:
	_apply_session_corals()


func _on_coral_damaged(_unique_id: String) -> void:
	_apply_session_corals()


func _on_wreck_visuals_changed(wreck_id: String) -> void:
	if wreck_id == _active_wreck_id:
		_apply_session_corals()


func _find_coral_controller() -> CoralMultiMeshController:
	if not coral_controller_path.is_empty():
		var explicit := get_node_or_null(coral_controller_path) as CoralMultiMeshController
		if explicit:
			return explicit

	if is_instance_valid(_active_coral_controller):
		return _active_coral_controller

	return get_tree().get_first_node_in_group("coral_multimesh") as CoralMultiMeshController


func _hook_aquarium_loader() -> void:
	var aquarium_lod := get_parent().get_node_or_null("Aquarium_LOD")
	if aquarium_lod is DepthSwitcher:
		if not aquarium_lod.content_loaded.is_connected(_on_aquarium_content_loaded):
			aquarium_lod.content_loaded.connect(_on_aquarium_content_loaded)
		for child in aquarium_lod.get_children():
			_on_aquarium_content_loaded(child)


func _on_aquarium_content_loaded(_content: Node) -> void:
	_ensure_coral_controller(_content)
	_apply_session_corals()


func _ensure_coral_controller(content: Node) -> CoralMultiMeshController:
	var existing := _find_coral_controller_in(content)
	if existing != null:
		_active_coral_controller = existing
		return existing
	if coral_controller_scene == null:
		push_warning("WreckSessionManager: no coral controller scene assigned.")
		return null
	var controller := coral_controller_scene.instantiate() as CoralMultiMeshController
	if controller == null:
		push_warning("WreckSessionManager: coral controller scene root is not a CoralMultiMeshController.")
		return null
	content.add_child(controller)
	_active_coral_controller = controller
	return controller


func _find_coral_controller_in(root: Node) -> CoralMultiMeshController:
	if root == null:
		return null
	if root is CoralMultiMeshController:
		return root
	for child in root.get_children():
		var found := _find_coral_controller_in(child)
		if found != null:
			return found
	return null


func _resolve_wreck_id() -> String:
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings == null or game_settings.current_level.is_empty():
		return ""
	var level_data := load(game_settings.current_level) as LevelData
	return level_data.nameID if level_data else ""


func _load_level_data() -> LevelData:
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings == null or game_settings.current_level.is_empty():
		return null
	return load(game_settings.current_level) as LevelData
