extends Node


@export var above_visible:Array[NodePath]
@export var below_visible:Array[NodePath]
@export var toggle_point_above:int = 1
@export var toggle_point_below:int = 1


func _ready() -> void:
	var lod_manager = get_tree().get_first_node_in_group("Player") as LOD_Manager
	if lod_manager:
		lod_manager.submersion_level_changed.connect(_on_depth_changed)
		_on_depth_changed(lod_manager.submersion_level)


func _on_depth_changed(depth_idx:int) -> void:
	var show_above = depth_idx <= toggle_point_above
	var show_below = depth_idx >= toggle_point_below

	_set_paths_visible(above_visible, show_above)
	_set_paths_visible(below_visible, show_below)


func _set_paths_visible(paths:Array[NodePath], is_visible:bool) -> void:
	for node_path in paths:
		var node = get_node_or_null(node_path)
		if node and "visible" in node:
			node.visible = is_visible
