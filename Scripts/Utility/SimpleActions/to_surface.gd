extends SimpleAction
class_name ToSurfaceAction

func do() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		push_error("ToSurfaceAction: Player group node not found")
		return
	var player_sm := player.get_parent().get_node_or_null("PlayerStateMachine") as PlayerStateMachine
	if player_sm == null:
		push_error("ToSurfaceAction: PlayerStateMachine not found")
		return
	player_sm.respawn()
