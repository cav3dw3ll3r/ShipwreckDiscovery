@tool
extends EditorScript

@export var folder_path: String = "res://Prefabs/Fish/Panhandle/" # folder with target scenes
@export var prefab_path: String = "res://Prefabs/scan_target.tscn"# the prefab to add
@export var scan_target_script_path: String = "res://scripts/ScanTarget.gd" # script to remove

func _run():
	var prefab_scene: PackedScene = load(prefab_path)
	if prefab_scene == null:
		push_error("Cannot load prefab: %s" % prefab_path)
		return
	
	_process_folder(folder_path, prefab_scene)


func _process_folder(path: String, prefab_scene: PackedScene):
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Cannot open folder: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_process_folder(path.path_join(file_name), prefab_scene)
		elif file_name.ends_with(".tscn"):
			_process_scene(path.path_join(file_name), prefab_scene)
		file_name = dir.get_next()
	dir.list_dir_end()


func _process_scene(scene_path: String, prefab_scene: PackedScene):
	var packed: PackedScene = load(scene_path)
	if not packed:
		return
	
	var scene_root = packed.instantiate()
	
	var to_remove = []
	# Remove any node with ScanTarget.gd attached
	for child in scene_root.get_children():
		if child is Area3D:
			to_remove.append(child)
	for node in to_remove:
		node.queue_free()

	# Check if prefab already exists
	var exists = false
	for child in scene_root.get_children():
		if child.scene_file_path == prefab_path:
			exists = true
			break
	
	if exists:
		return

	# Add prefab
	var prefab_instance = prefab_scene.instantiate()
	scene_root.add_child(prefab_instance)
	prefab_instance.owner = scene_root  # necessary for saving

	var new_packed = PackedScene.new()
	new_packed.pack(scene_root)
	var err = ResourceSaver.save(new_packed, scene_path)
	if err == OK:
		pass
	else:
		push_error("Failed to save: %s" % scene_path)
