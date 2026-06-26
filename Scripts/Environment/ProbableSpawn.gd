extends Node

@export var spawnedObject:PackedScene
@export_range(0,1,0.01) var spawnChance:float

func _ready() -> void:
	var rand = randf()
	if(rand<spawnChance):
		get_parent().add_child(spawnedObject.instantiate())
	
	queue_free()
