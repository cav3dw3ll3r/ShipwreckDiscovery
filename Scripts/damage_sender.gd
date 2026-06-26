extends Area3D

@export var damage: int = 10
@export var stagger:int = 10

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage,stagger, self)
