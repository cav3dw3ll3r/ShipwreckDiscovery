extends Area3D

@export var cooldown_seconds: float = 2.0

var _cooldown_until_msec := 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 32
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if Time.get_ticks_msec() < _cooldown_until_msec:
		return
	if not _is_head_damage_receiver(body):
		return

	var session_manager := get_tree().root.get_node_or_null("SessionManager")
	if session_manager == null or not session_manager.has_method("end_current_dive"):
		return

	if session_manager.end_current_dive():
		_cooldown_until_msec = Time.get_ticks_msec() + int(cooldown_seconds * 1000.0)


func _is_head_damage_receiver(body: Node) -> bool:
	return body is DamageReciever and body.get_parent() != null and body.get_parent().name == "XRCamera3D"
