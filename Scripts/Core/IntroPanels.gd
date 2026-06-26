extends Node3D

## Curve for following the camera
@export var follow_speed : Curve

@onready var _camera = get_tree().get_first_node_in_group("Player")

var _panels: Array[ComicPanel] = []
var _sequence_started: bool = false


func _ready() -> void:
	global_position.y = _camera.global_position.y
	var staging = XRTools.find_xr_ancestor(self, "*", "XRToolsStaging") as XRToolsStaging
	if staging and not staging.scene_visible.is_connected(_on_scene_visible):
		staging.scene_visible.connect(_on_scene_visible, CONNECT_ONE_SHOT)
	else:
		call_deferred("_begin_sequence")

func _process(delta):
	# Skip if in editor
	if Engine.is_editor_hint():
		return

	# Skip if no camera to track
	if !_camera:
		return

	# Get the camera direction (horizontal only)
	var camera_dir = _camera.global_transform.basis.z
	camera_dir.y = 0.0
	camera_dir = camera_dir.normalized()

	# Get the loading screen direction
	var loading_screen_dir := global_transform.basis.z

	# Get the angle
	var angle := loading_screen_dir.signed_angle_to(camera_dir, Vector3.UP)
	if angle == 0:
		return
	
	# Do rotation based on the curve
	global_transform.basis = global_transform.basis.rotated(
			Vector3.UP * sign(angle),
			follow_speed.sample_baked(abs(angle) / PI) * delta
	).orthonormalized()

func _on_scene_visible(scene: Node, _user_data) -> void:
	if scene != get_parent():
		return
	_begin_sequence()


func _begin_sequence() -> void:
	if _sequence_started:
		return
	_sequence_started = true
	_setup_panels()
	_play_sequence()


func _setup_panels() -> void:
	_panels.clear()
	for child in get_children():
		if child is ComicPanel:
			_panels.append(child)


func _play_sequence() -> void:
	if _panels.is_empty():
		_launch_game()
		return

	for panel in _panels:
		await panel.switch_on()

	_launch_game()


func _launch_game() -> void:
	var launcher := get_node("../Launcher") as Launcher
	if launcher:
		launcher.launch()
