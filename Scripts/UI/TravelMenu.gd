

extends Node

const TRAVEL_WRECK_PANEL := preload("res://Prefabs/UI/travel_wreck_panel.tscn")

@onready var levelsPreloader = $LevelPreloader
@onready var level_list = $ScrollContainer/LevelList
@onready var eyelids:Progress_Animator = get_tree().get_first_node_in_group("Player").get_node("Eyelids")
@onready var target:Node3D = null

var levels: Array[LevelData] = []
var selectedLevel:String
var active_level_resource_path:String
var active_level_scene_path:String
var _wreck_panels: Dictionary = {}

func _ready() -> void:
	if not SessionManager.wreck_visuals_changed.is_connected(_on_wreck_visuals_changed):
		SessionManager.wreck_visuals_changed.connect(_on_wreck_visuals_changed)
	await get_tree().process_frame
	SaveLoad.restore_all()
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("gather_available_levels")

func _exit_tree() -> void:
	if SessionManager.wreck_visuals_changed.is_connected(_on_wreck_visuals_changed):
		SessionManager.wreck_visuals_changed.disconnect(_on_wreck_visuals_changed)

func gather_available_levels():
	if not get_tree().get_first_node_in_group("GameSettings"): return
	var active_level_data:LevelData = load(get_tree().get_first_node_in_group("GameSettings").current_level) as LevelData
	active_level_resource_path = active_level_data.resource_path
	active_level_scene_path = active_level_data.scene_path
	levels.clear()
	for nAme in levelsPreloader.get_resource_list():
		var level = levelsPreloader.get_resource(nAme)
		if level is LevelData:
			levels.append(level)
	SessionManager.register_level_blueprints(levels)
	await get_tree().process_frame
	setup_panels()

func setup_panels():
	_wreck_panels.clear()
	for level in levels:
		var panel: TravelWreckPanel = TRAVEL_WRECK_PANEL.instantiate()
		level_list.add_child(panel)
		panel.setup(level, level.scene_path == active_level_scene_path)
		_wreck_panels[level.nameID] = panel
		panel.travel_pressed.connect(_on_panel_travel.bind(level))
		panel.instant_dive_pressed.connect(_on_panel_instant_dive.bind(level))

func refresh_display() -> void:
	for panel in _wreck_panels.values():
		if is_instance_valid(panel) and panel.has_method("refresh_display"):
			panel.refresh_display()

func _on_wreck_visuals_changed(wreck_id: String) -> void:
	var panel: Variant = _wreck_panels.get(wreck_id, null)
	if panel != null and is_instance_valid(panel) and panel.has_method("refresh_display"):
		panel.refresh_display()

func _on_panel_travel(level: LevelData) -> void:
	active_level_resource_path = level.resource_path
	selectedLevel = level.scene_path
	launchLevel()

func _on_panel_instant_dive(level: LevelData) -> void:
	active_level_resource_path = level.resource_path
	selectedLevel = level.scene_path
	instantDive()

func launchLevel():
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings:
		var is_launcher_scene := get_tree().get_first_node_in_group("Launcher") != null
		var is_travel_to_new_wreck := selectedLevel != active_level_scene_path
		game_settings.pending_auto_instant_dive = is_travel_to_new_wreck and not is_launcher_scene
		game_settings.current_level = active_level_resource_path
		game_settings.apply_settings()
	SaveLoad.save_all()
	if eyelids:
		eyelids.done.connect(true_launch, CONNECT_ONE_SHOT)
		eyelids.set_off()
	else:
		call_deferred("true_launch")

func instantDive():
	target = get_tree().get_first_node_in_group("InstantDive")
	if not target: return
	if eyelids:
		if eyelids.done.is_connected(true_launch):
			eyelids.done.disconnect(true_launch)
		eyelids.done.connect(_on_instant_dive_eyelids_done, CONNECT_ONE_SHOT)
		eyelids.set_off()
	else:
		call_deferred("true_instant_dive")

func _on_instant_dive_eyelids_done():
	true_instant_dive()
	if eyelids:
		eyelids.schedule_set_on_after(1.5)

func true_instant_dive():
	# Ensure anything currently held by the player is released before
	# teleporting / changing scenes, to avoid stale XR grab references.
	_destroy_held_items_before_travel()
	var player_body:XRToolsPlayerBody = get_tree().get_first_node_in_group("Player").get_node("../XRToolsPlayerBody")
	if target and player_body:
		player_body.teleport(target.global_transform)
	if not (target and player_body):
		pass

func true_launch():
	if eyelids and eyelids.done.is_connected(true_launch):
		eyelids.done.disconnect(true_launch)
	# Always unequip/let go items before loading the new scene.
	_destroy_held_items_before_travel()
	get_tree().get_first_node_in_group("Player").get_node("Vignette").set_off()
	var scene_base : XRToolsSceneBase = XRTools.find_xr_ancestor(self, "*", "XRToolsSceneBase")
	if not scene_base:
		return

	var spawn_point := "Respawn"
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings and game_settings.pending_auto_instant_dive:
		spawn_point = "InstantDive"
		game_settings.pending_auto_instant_dive = false
	scene_base.load_scene(selectedLevel, spawn_point)

func _destroy_held_items_before_travel() -> void:
	for n in get_tree().get_nodes_in_group("EquipmentHolder"):
		if n is Equipment_Holder and is_instance_valid(n):
			(n as Equipment_Holder).clear_equipped_for_travel()

	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return

	_destroy_item_in_pickup(XRToolsFunctionPickup.find_left(player))
	_destroy_item_in_pickup(XRToolsFunctionPickup.find_right(player))

func _destroy_item_in_pickup(pickup: XRToolsFunctionPickup) -> void:
	if pickup == null:
		return

	var held := pickup.picked_up_object
	if not is_instance_valid(held):
		pickup.picked_up_object = null
		return

	pickup.drop_object()
	# Intentionally do not queue_free the held object here. We just want to
	# release/detach anything in the player's hands before travel.
