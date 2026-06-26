extends Node
## Runs after [code]XRToolsGrabDriver[/code] (priority -80) so the spear can reorient; delegates to
## [method SpearPickable.apply_inter_hand_shaft_basis_post].

const POST_PRIORITY: int = -60


func _init() -> void:
	process_physics_priority = POST_PRIORITY


func _ready() -> void:
	if not get_parent() is SpearPickable:
		push_error("Spear_InterHandPostAlign: parent must be SpearPickable.")
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	var p: SpearPickable = get_parent() as SpearPickable
	if p:
		p.apply_inter_hand_shaft_basis_post()
