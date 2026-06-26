@tool
extends Node3D


@export var particle_prefab: PackedScene
@export var global_x_max = 500
@export var global_x_min = -500
@export var global_y_max = -10
@export var global_y_min = -50
@export var global_z_max = 500
@export var global_z_min = -500

@export var spacing = 50.0  # Distance between particle emitters

@export var is_generating_silt: bool = false:
	set = generate_silt

func generate_silt(val:bool):
	if not val: return
	
	for child in get_children():
		child.queue_free()
	for x in range(global_x_min, global_x_max + 1, spacing):
		for y in range(global_y_min, global_y_max + 1, spacing):
			for z in range(global_z_min, global_z_max + 1, spacing):
				spawn_particle(Vector3(x, y, z))
	
	val = false


func spawn_particle(pos: Vector3):
	if not particle_prefab:
		return
	var instance = particle_prefab.instantiate()
	instance.global_transform.origin = pos
	add_child(instance)
	instance.amount = abs(instance.global_position.y)/3
	instance.emitting = true
	instance.one_shot = false
	if Engine.is_editor_hint():
		instance.owner = EditorInterface.get_edited_scene_root()
	if instance.has_method("restart"):
		instance.restart()
	
