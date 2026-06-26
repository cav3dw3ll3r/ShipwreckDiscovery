extends Node
class_name DepthSwitcher

# Depth 0 = surface, 3 = at wreck. Above = surface/shallow (0-1), below = deep (2-3).
@export var above_prefab: PackedScene  # shown at surface / shallow (e.g. top-down wreck, far boat)
@export var below_prefab: PackedScene  # shown when deep (e.g. assembled wreck, near boat)
@export var switch_to_below: int = 2   # depth index >= this: show below_prefab
@export var switch_to_above: int = 1   # depth index <= this: show above_prefab

var use_above: bool = true  # true when currently showing above_prefab

signal content_loaded(node: Node)

func _ready() -> void:
	var lod_manager = get_tree().get_first_node_in_group("Player") as LOD_Manager
	if lod_manager:
		lod_manager.submersion_level_changed.connect(_on_depth_changed)
	set_above()

func set_above() -> void:
	for c in get_children():
		c.queue_free() 
	if above_prefab: 
		var above = above_prefab.instantiate()
		add_child(above)

func set_below() -> void:
	for c in get_children():
		c.queue_free()
	if below_prefab:
		var below = below_prefab.instantiate()
		add_child(below)
		content_loaded.emit(below)

func _on_depth_changed(depth_idx: int) -> void:
	if depth_idx >= switch_to_below and use_above:
		set_below()
		use_above = false
	if depth_idx <= switch_to_above and not use_above:
		set_above()
		use_above = true
