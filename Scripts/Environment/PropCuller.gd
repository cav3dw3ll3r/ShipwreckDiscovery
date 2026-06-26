# PropCullerTimer.gd
# DEPRECATED: Not used in Optimized_Base / going forward; kept for reference.
# Attach this to a Timer node in your scene
extends Timer

@export var max_distance: float = 4.0        # max visible distance
@export var underwater_only: bool = false    # only hide props when underwater

@onready var camera = get_viewport().get_camera_3d()
var props: Array = []

func _ready():
	# Find all props in the "props" group
	props = get_tree().get_nodes_in_group("props")

	# Connect the timeout signal to the update function
	connect("timeout", Callable(self, "_update_prop_visibility"))

	# Initial update immediately
	_update_prop_visibility()
	
	start()


func _update_prop_visibility():
	if not camera:
		return

	var cam_pos = camera.global_position

	for prop in props:
		if not prop is MeshInstance3D:
			continue  # skip deleted nodes and not MeshInstance3D

		# Optional: only hide if underwater
		if underwater_only and cam_pos.y > 0.0:  # adjust to your water level
			prop.visible = true
			continue

		var dist = prop.global_position.distance_to(cam_pos)
		prop.visible = dist <= max_distance
		
		await get_tree().process_frame
	
	start()
