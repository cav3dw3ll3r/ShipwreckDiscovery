extends Node3D

@onready var animator = $AnimationPlayer
@onready var head:Node3D = get_tree().get_first_node_in_group("Player")
@onready var watch_menu = $MainMenu

const TOP_LEVEL_MENU_SCENE := preload("res://Prefabs/UI/WatchSubMenus/top_level_menu.tscn")

var expanded = false
var look_time:float = 0.0 
const look_time_threshold = 0.2
const alignment_threshold = 0.85

func _ready() -> void:
	# Ensure the stowed menu is rendered once at startup before we disable updates.
	animator.play("Watch_Pop_In")
	animator.seek(animator.current_animation_length, true)
	_set_watch_active(true)
	_disable_watch_after_initial_render()


func _disable_watch_after_initial_render() -> void:
	await get_tree().process_frame
	if not expanded:
		_set_watch_active(false)


func _process(delta: float) -> void:
	if head == null:
		return
	var watch_facing = global_basis.z.normalized()
	var head_facing = head.global_basis.z.normalized()
	var alignment = head_facing.dot(watch_facing)
	if(alignment > alignment_threshold and not expanded):
		look_time+=delta
		if(look_time>look_time_threshold):
			expanded = true
			_set_watch_active(true)
			animator.play("Watch_Pop_Out")
	if(alignment < alignment_threshold and expanded):
		look_time=0
		expanded = false
		_set_watch_active(false)
		animator.play("Watch_Pop_In")
	pass
	#print("Dot Product: "+headTransform.transform.basis.z,transform.basis.z


func _set_watch_active(is_active: bool) -> void:
	if watch_menu == null or not watch_menu.has_node("Viewport"):
		return

	var viewport := watch_menu.get_node("Viewport") as SubViewport
	if viewport == null:
		return

	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED
	)
