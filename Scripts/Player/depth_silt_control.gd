extends MeshInstance3D
class_name SiltController


@onready var material=get_active_material(0)

@export_category("Depth Range")
@export var min_depth: float = 2.0     # Depth where silt starts appearing
@export var max_depth: float = 15.0    # Depth where silt is fully visible

@export_category("Intensity Range")
@export var min_intensity: float = 0.0
@export var max_intensity: float = 0.4

@export_category("Response")
@export var response_speed: float = 3.0  # Higher = snappier, lower = floatier

@export_category("Depth Source")
@export var depth_source: Node3D        # Usually your Camera3D

var _current_intensity: float = 0.0


func _ready() -> void:
	if not depth_source:
		push_warning("SiltController: No depth_source assigned.")


func _process(delta: float) -> void:
	if not material or not depth_source:
		return

	var depth := _get_depth()

	# Map depth into 0–1
	var t := inverse_lerp(min_depth, max_depth, depth)
	t = clamp(t, 0.0, 1.0)

	# Map to intensity range
	var target_intensity = lerp(min_intensity, max_intensity, t)

	# Smooth response (exponential decay smoothing)
	_current_intensity = lerp(
		_current_intensity,
		target_intensity,
		1.0 - exp(-response_speed * delta)
	)

	material.set_shader_parameter("silt_intensity", _current_intensity)


func _get_depth() -> float:
	# Assumes water surface at y = 0
	# Deeper underwater = more negative Y
	return max(0.0, -depth_source.global_position.y)
