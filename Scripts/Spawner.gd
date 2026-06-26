extends Node3D

class_name Spawner

@export var respect_anchor = false
@export var spawn_count:int=10
@export var spawn_options:Array[PackedScene] = []
@export var spawn_radius:float=120.0
@export var max_spawn_height:float=0.0
@export var min_spawn_height:float = -100

var despawn_distance = 0.0
var player
var spawn_list:Array = []
var tickTime = 0.5
var timeSinceTick = 0.5
var spawn_anchors:Array = []

@onready var game_settings:GameSettings = get_tree().get_first_node_in_group("GameSettings")

func _ready():
	if(respect_anchor):
		spawn_anchors = get_tree().get_nodes_in_group("Anchor")
	if(respect_anchor):
		despawn_distance = spawn_radius*3.0
	else:
		despawn_distance = spawn_radius * 1.2

func _process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			return
	
	timeSinceTick -= delta
	if timeSinceTick <= 0.0:
		timeSinceTick = tickTime
		start_manage_spawns()

func get_nearest_anchor() -> Node3D:
	var nearest_anchor: Node3D = null
	var nearest_distance = INF
	var player_position = player.global_position

	for anchor in spawn_anchors:
		var distance = player_position.distance_to(anchor.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_anchor = anchor
		await get_tree().process_frame  # optional, if spawn_anchors is large

	return nearest_anchor

func _manage_spawns_coroutine():
	if not game_settings:
		game_settings = get_tree().get_first_node_in_group("GameSettings")
		return
	
	var nearest_anchor = await get_nearest_anchor()
	var anchor_distance=0
	if(nearest_anchor):
		anchor_distance = player.global_position.distance_to(nearest_anchor.global_position)
	
	if((not respect_anchor) or anchor_distance<spawn_radius*2.0):
		while spawn_list.size() < spawn_count and game_settings.current_fish<game_settings.max_fish:
			if(respect_anchor):
				await anchored_spawn()
			else:
				await global_spawn()
			await get_tree().process_frame
	# Despawn entities too far from player
	for instance in spawn_list.duplicate():
		if not instance:
			continue
		if player.global_position.distance_to(instance.global_position) > despawn_distance or game_settings.current_fish>game_settings.max_fish:
			instance.queue_free()
			spawn_list.erase(instance)
			game_settings.current_fish-=1
			await get_tree().process_frame  # optional: yield to next frame if doing heavy work

func start_manage_spawns():
	# Start the coroutine without blocking _process
	call_deferred("_manage_spawns_coroutine")

func anchored_spawn():
	var nearest_anchor = await get_nearest_anchor()
	if nearest_anchor == null:
		push_warning("No valid anchors found.")
		return
	
	var anchor_position = nearest_anchor.global_position
	var anchor_distance = player.global_position.distance_to(anchor_position)

	if anchor_distance > spawn_radius*2.0:
		return

	do_spawn(nearest_anchor.global_position, anchor_position.y+min_spawn_height,anchor_position.y+max_spawn_height)


func global_spawn():
	var lower_bound = player.global_position.y - 20
	var upper_bound = player.global_position.y + 20

	if upper_bound < min_spawn_height or lower_bound > max_spawn_height:
		return

	do_spawn(player.global_position,min_spawn_height,max_spawn_height)


func do_spawn(origin: Vector3, min_global_y: float, max_global_y: float):
	if spawn_options.is_empty():
		push_warning("No spawn options assigned to spawner.")
		return

	var index = randi() % spawn_options.size()
	var spawnable: PackedScene = spawn_options[index]
	var spawned = spawnable.instantiate()

	# Spherical coordinates
	var theta = randf_range(0, 2.0 * PI)
	var phi = randf_range(0, PI)  # full sphere
	var r = spawn_radius

	var offset = Vector3(
		r * sin(phi) * cos(theta),
		r * cos(phi),
		r * sin(phi) * sin(theta)
	)

	var spawn_position = origin + offset
	var spawn_scale = randf_range(0.9,1.1)
	add_child(spawned)
	spawned.scale = Vector3(spawn_scale, spawn_scale,spawn_scale)
	spawned.global_position = spawn_position
	spawned.global_position.y = clamp(spawned.global_position.y, min_global_y, max_global_y)

	# Direction toward offset, flattened on Y plane
	var target_dir = (offset - spawn_position)
	target_dir.y = 0
	target_dir = target_dir.normalized()

	# Convert to yaw
	var yaw = atan2(target_dir.x, target_dir.z)

	# Add random wobble
	yaw += deg_to_rad(randf_range(-5.0, 5.0))

	spawned.global_rotation = Vector3(0, yaw, 0)

	spawn_list.append(spawned)
	game_settings.current_fish += 1
