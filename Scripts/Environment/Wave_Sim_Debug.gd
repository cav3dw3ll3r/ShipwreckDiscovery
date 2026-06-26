extends MultiMeshInstance3D
class_name Wave_Visualizer

@export var grid_width: int = 32        # number of samples in X
@export var grid_depth: int = 32        # number of samples in Z
@export var spacing: int = 1        # meters between samples

@onready var waves: Waves = get_tree().get_first_node_in_group("Waves")
@onready var mm_instance := MultiMeshInstance3D.new()
var mm :MultiMesh

func _ready():
	assert(waves != null)
	mm = multimesh
	mm.instance_count = (grid_width*grid_depth) 
	_build_grid()

func _build_grid():
	var idx := 0
	var half_w := grid_width * spacing * 0.5
	var half_d := grid_depth * spacing * 0.5

	for x in range(grid_width):
		for z in range(grid_depth):
			var world_x := x * spacing - half_w
			var world_z := z * spacing - half_d

			var t := Transform3D.IDENTITY
			t.origin = Vector3(world_x, 0.0, world_z)

			multimesh.set_instance_transform(idx, t)
			idx += 1

func _process(_delta):
	var idx := 0

	for x in range(grid_width):
		for z in range(grid_depth):
			var tr = mm.get_instance_transform(idx)

			# 1. Convert local origin to absolute World Coordinates
			var global_pos = global_transform * tr.origin

			# 2. Feed GLOBAL X and Z into the wave function
			var h = waves.getWaveHeight(global_pos.x, global_pos.z)

			# 3. Apply the height back locally for the multimesh
			tr.origin.y = h
			mm.set_instance_transform(idx, tr)

			idx += 1
