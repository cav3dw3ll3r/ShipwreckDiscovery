extends MeshInstance3D

class_name NumberCallout

var player
var life_time = 0
var max_life = 3.0
var material

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	material = mesh.surface_get_material(0)
	
func set_number(number):
	var int_number = int(number)
	mesh.text = "+"+str(int_number)

func _process(delta: float) -> void:
	life_time+=delta
	if(life_time<1.0):
		scale = Vector3(life_time,life_time,life_time)
	look_at(player.global_position)
	rotate(Vector3.UP,PI)
	position.y+=delta*0.01
	if life_time>max_life:
		queue_free()
