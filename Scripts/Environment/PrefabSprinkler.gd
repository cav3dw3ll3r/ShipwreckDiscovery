@tool
extends Node3D

@export var prefab: PackedScene
@export var num_walkers: int = 20
@export var max_steps: int = 100
@export var step_size: float = 5.0
@export var spawn_chance: float = 0.15
@export var collision_mask: int = 1
@export var generate_walks: bool = false:
	set = on_generate_walks

var spawned_positions = {}

func on_generate_walks(value: bool) -> void:
	if value:
		_generate_walks()
		generate_walks = false

func _ready() -> void:
	_generate_walks()

func _generate_walks() -> void:
	for child in get_children():
		child.queue_free()
	spawned_positions.clear()
	if prefab == null:
		push_error("RandomWalkSpawner: `prefab` is not assigned!")
		return

	var base_directions = {
		"east":  Vector2(1, 0),
		"west":  Vector2(-1, 0),
		"south": Vector2(0, 1),
		"north": Vector2(0, -1)
	}

	var dir_keys = base_directions.keys()
	var space_state = get_world_3d().direct_space_state

	for walker in num_walkers:
		var walker_pos = Vector2.ZERO

		# Pick a direction to block
		var blocked_key = dir_keys.pick_random()
		var allowed_directions = []

		for key in dir_keys:
			if key != blocked_key:
				allowed_directions.append(base_directions[key])

		for step in max_steps:
			if randf() <= spawn_chance and not Vector2(int(walker_pos.x),int(walker_pos.y)) in spawned_positions:
				var world_pos = Vector3(walker_pos.x, -10.0, walker_pos.y)
				var ray = PhysicsRayQueryParameters3D.new()
				ray.from = world_pos
				ray.to = world_pos - Vector3.UP * 1000.0
				ray.collision_mask = collision_mask
				var hit = space_state.intersect_ray(ray)

				if hit:
					var instance = prefab.instantiate()
					instance.transform.origin = Vector3(walker_pos.x, hit.position.y + 0.5, walker_pos.y)
					instance.rotation.y = randf_range(0,360)
					add_child(instance, true)
					if Engine.is_editor_hint():
						instance.owner = EditorInterface.get_edited_scene_root()
					spawned_positions[Vector2(int(walker_pos.x),int(walker_pos.y))]=true

			# Move walker randomly in allowed directions (excluding the blocked one)
			walker_pos += allowed_directions.pick_random() * step_size
