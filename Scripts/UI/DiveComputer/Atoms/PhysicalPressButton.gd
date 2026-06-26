extends Node3D
class_name PhysicalPressButton

const FINGERTIP_LAYER := 512
const PRESS_FEEDBACK_DURATION_SEC := 0.12

var is_interaction_active: bool = false
var is_primed: bool = false

@export var lit_mesh: MeshInstance3D
@export var disabled_mat: StandardMaterial3D
@export var enabled_mat: StandardMaterial3D
@export var pressed_mat: StandardMaterial3D

@onready var _area: Area3D = $Area3D

var _overlap_count: int = 0
var _press_feedback_timer: SceneTreeTimer

signal pressed


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_area.monitoring = true
	_area.monitorable = true
	_apply_material(_material_for_state())


func _on_body_entered(body: Node3D) -> void:
	if not _is_fingertip_body(body):
		return
	_overlap_count += 1


func _on_body_exited(body: Node3D) -> void:
	if not _is_fingertip_body(body):
		return
	_overlap_count = maxi(0, _overlap_count - 1)


func _is_fingertip_body(body: Node) -> bool:
	var collision_object := body as CollisionObject3D
	return collision_object != null and (collision_object.collision_layer & FINGERTIP_LAYER) != 0


func has_finger_overlap() -> bool:
	return _overlap_count > 0


func set_interaction_active(active: bool) -> void:
	is_interaction_active = active
	if not active:
		set_primed(false)
		if not is_primed:
			_apply_material(disabled_mat)


func set_primed(primed: bool) -> void:
	if is_primed == primed:
		return
	is_primed = primed
	_apply_material(_material_for_state())


func activate() -> void:
	play_press_feedback()
	pressed.emit()


func play_press_feedback() -> void:
	if lit_mesh == null or pressed_mat == null:
		return
	_apply_material(pressed_mat)
	if _press_feedback_timer != null and is_instance_valid(_press_feedback_timer):
		_press_feedback_timer.timeout.disconnect(_on_press_feedback_finished)
	_press_feedback_timer = get_tree().create_timer(PRESS_FEEDBACK_DURATION_SEC)
	_press_feedback_timer.timeout.connect(_on_press_feedback_finished)


func _on_press_feedback_finished() -> void:
	_apply_material(_material_for_state())


func _material_for_state() -> StandardMaterial3D:
	if is_primed and enabled_mat != null:
		return enabled_mat
	return disabled_mat


func _apply_material(mat: StandardMaterial3D) -> void:
	if lit_mesh != null and mat != null:
		lit_mesh.set_surface_override_material(1, mat)
