extends StaticBody3D

@export var float_offset := 0
@export var water_drag := 0.05
@export var water_angular_drag := 0.05

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var water

var submerged := false

# Called when the node enters the scene tree for the first time.
func _ready():
	water = get_tree().get_nodes_in_group("Waves")[0]
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _physics_process(delta):
	global_position.y = water.getWaveHeight(global_position.x,global_position.z) - float_offset
