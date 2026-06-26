extends ColorRect
class_name ScannerDisplay

signal scan_completed(target: Spotlight_Target, world_position: Vector3)

@export var max_angle_deg: float = 60.0

var _radar := ScannerRadar.new()
var _scan_point: Node3D
var _spotlight: EntitySpotlight
var _left_controller: XRController3D


func _ready() -> void:
	_radar.max_angle_deg = max_angle_deg
	_scan_point = get_tree().get_first_node_in_group("Scanner")
	_spotlight = get_tree().get_first_node_in_group("Spotlight")
	_left_controller = XRHelpers.get_xr_controller(self)
	_radar.scan_point = _scan_point
	_radar.spotlight = _spotlight
	_radar.display_material = material as ShaderMaterial


func _process(delta: float) -> void:
	_radar.update_display(get_tree())
	if _left_controller:
		_radar.handle_trigger_input(_left_controller)

	var completed_target := _radar.tick_scan(delta)
	if completed_target != null:
		scan_completed.emit(completed_target, _radar.get_target_world_position())
