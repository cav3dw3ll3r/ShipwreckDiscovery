extends Node3D

var waves:Waves

var heightOffset = 1.2

@onready var frontMarker = $FrontMarker
@onready var rearMarker = $RearMarker

var target_y: float
var target_rot: float
var boat_length:float

var _lod: LOD_Manager
var _boat_lod: int = 0

func _ready() -> void:
	boat_length = (frontMarker.position-rearMarker.position).length()
	waves = get_tree().get_first_node_in_group("Waves")
	_lod = get_tree().get_first_node_in_group("Player") as LOD_Manager
	if _lod and _lod.is_boat_lod_active():
		_boat_lod = maxi(0, _lod.boat_lod_level)
		_lod.boat_lod_changed.connect(_on_boat_lod_changed)

func _on_boat_lod_changed(level: int) -> void:
	_boat_lod = maxi(0, level)


func _process(delta: float) -> void:
	global_position.y = lerp(global_position.y, target_y, delta*3.)
	rotation.x = lerp_angle(rotation.x, target_rot, delta*3.)

func _physics_process(delta: float) -> void:
	if _lod and _lod.is_boat_lod_active() and _boat_lod >= 2:
		return
	if not waves: return
	if not waves.active: return
	# Get wave height at current position
	var center_height = waves.getWaveHeight(global_position.x, global_position.z) - heightOffset

	# Define front and rear sample points
	var front_pos = frontMarker.global_position
	var rear_pos = rearMarker.global_position

	# Get wave heights at those points
	var front_height = waves.getWaveHeight(front_pos.x, front_pos.z)-heightOffset
	var rear_height = waves.getWaveHeight(rear_pos.x, rear_pos.z)-heightOffset
	var angleToFront = atan2(front_height-rear_height,boat_length)
	#var angleToBack = atan2(rear_height-center_height,boat_length/2)
	
	#determine whether to flip the sign
	if(true):
		angleToFront*=-1.0
	#if(rear_height<center_height):
		#angleToBack*=-1.0
	
	target_rot = (angleToFront)
	
	target_y = center_height
	
