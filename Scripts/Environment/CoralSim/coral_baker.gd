@tool
extends EditorScript

@export_file("*.tres") var level_data_path: String = "res://Resources/Levels/MissJoanne.tres"
@export var require_scene_match: bool = true


func _run() -> void:
	if level_data_path.is_empty():
		push_error("CoralBaker: Assign a LevelData .tres path to level_data_path.")
		return

	var level_data := load(level_data_path) as LevelData
	if level_data == null:
		push_error("CoralBaker: Failed to load LevelData at %s" % level_data_path)
		return

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("CoralBaker: No scene is open in the editor.")
		return

	if require_scene_match and root.scene_file_path != level_data.scene_path:
		push_error(
			"CoralBaker: Edited scene (%s) does not match LevelData.scene_path (%s)."
			% [root.scene_file_path, level_data.scene_path]
		)
		return

	var corals: Array[CoralData] = []
	_collect_static_corals(root, corals)

	level_data.initial_corals = corals
	var err := ResourceSaver.save(level_data, level_data_path)
	if err != OK:
		push_error("CoralBaker: Failed to save LevelData (%s)." % error_string(err))
		return

	print("CoralBaker: Baked %d coral(s) into %s" % [corals.size(), level_data_path])


func _collect_static_corals(node: Node, out: Array[CoralData]) -> void:
	if node.is_in_group("static_coral") and node.has_method("bake"):
		out.append(node.bake())

	for child in node.get_children():
		_collect_static_corals(child, out)
