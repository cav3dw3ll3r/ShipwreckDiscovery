extends Node3D

## Placeholder burst: remove after a short lifetime. Replace root children with real VFX as needed.


func _ready() -> void:
	add_to_group(DeadLionfish.GROUP_ZK_MOTION_LOCK_CARRIER)
	get_tree().create_timer(2.0).timeout.connect(queue_free)
