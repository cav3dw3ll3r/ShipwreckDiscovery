@tool
extends MeshInstance3D
class_name CylinderConnector

## The anchor node on the hand side.
@export var hand_anchor: Node3D:
	set(v):
		hand_anchor = v
		update_transform()

@export var left_hand_anchor: Node3D:
	set(v):
		left_hand_anchor = v
		if _use_left_hand_anchor:
			hand_anchor = v
		else:
			update_transform()

@export var right_hand_anchor: Node3D:
	set(v):
		right_hand_anchor = v
		if not _use_left_hand_anchor:
			hand_anchor = v
		else:
			update_transform()

## The anchor node on the knot side.
@export var knot_anchor: Node3D:
	set(v):
		knot_anchor = v
		update_transform()

@export_group("Thickness Taper")
@export_range(0.001, 2.0, 0.001) var hand_radius: float = 0.05:
	set(v):
		hand_radius = v
		_update_mesh_radii()
@export_range(0.001, 2.0, 0.001) var knot_radius: float = 0.05:
	set(v):
		knot_radius = v
		_update_mesh_radii()

var _use_left_hand_anchor: bool = false


func use_left_hand_anchor(is_left_hand: bool) -> void:
	_use_left_hand_anchor = is_left_hand
	var next_anchor := left_hand_anchor if is_left_hand else right_hand_anchor
	if is_instance_valid(next_anchor):
		hand_anchor = next_anchor
	else:
		update_transform()


func _ready() -> void:
	process_priority = 10
	_update_mesh_radii()
	update_transform()

func _process(_delta: float) -> void:
	update_transform()

func update_transform() -> void:
	if not is_inside_tree() or not hand_anchor or not knot_anchor:
		return
	if not hand_anchor.is_inside_tree() or not knot_anchor.is_inside_tree():
		return
		
	var p_start: Vector3 = hand_anchor.global_position
	var p_end: Vector3 = knot_anchor.global_position
	
	# 1. Calculate the distance and update the primitive mesh height directly
	var distance: float = p_start.distance_to(p_end)
	if distance < 0.001:
		return
		
	var cyl := mesh as CylinderMesh
	if cyl:
		cyl.height = distance*1/scale.x

	# 2. Position the cylinder exactly at the mid-point between anchors
	global_position = p_start.lerp(p_end, 0.5)
	
	# 3. Orient the cylinder. Look_at aligns the -Z axis, so we tilt 
	# 90 degrees on X to map the cylinder's vertical Y-axis between the points.
	look_at(p_end, Vector3.UP)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

func _update_mesh_radii() -> void:
	var cyl := mesh as CylinderMesh
	if cyl:
		# Native CylinderMesh: bottom is hand, top is knot
		cyl.bottom_radius = hand_radius
		cyl.top_radius = knot_radius
