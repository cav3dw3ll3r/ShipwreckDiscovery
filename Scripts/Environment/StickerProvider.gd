extends Node

@onready var univ_small = $Universal_Small
@onready var univ_large = $Universal_Large

var large_sticker_dict = {}
var small_sticker_dict = {}

func populate_stickers(group_id):
	randomize()
	add_universal_stickers(true,large_sticker_dict)
	add_group_stickers(group_id,true,large_sticker_dict)
	add_universal_stickers(false,small_sticker_dict)
	add_group_stickers(group_id,false,small_sticker_dict)

	for sticker_template:StickerTemplate in get_tree().get_nodes_in_group("Sticker"):
		var tgt_dict:Dictionary
		if sticker_template.is_large_sticker:
			tgt_dict = large_sticker_dict
		else:
			tgt_dict = small_sticker_dict
		var sticker_prefab:PackedScene = get_sticker(tgt_dict)
		if not sticker_prefab:
			continue
		var sticker:Node3D = sticker_prefab.instantiate()
		sticker_template.add_child(sticker)
		sticker.position = Vector3.ZERO
		sticker.rotation = Vector3.ZERO

func get_sticker(sticker_dict:Dictionary):
		# Pick a random key and return the corresponding PackedScene
	var keys = sticker_dict.keys()
	if keys.size() == 0:
		push_warning("No stickers available")
		return null
	
	var random_key = keys.pick_random()
	var result = sticker_dict[random_key]
	sticker_dict.erase(random_key)
	return result

func add_universal_stickers(is_large:bool, sticker_dict:Dictionary)->void:
	var size_suffix = "_Large" if is_large else "_Small"
	var tgt_preloader: ResourcePreloader = get_node_or_null("Universal" + size_suffix)
	
	if tgt_preloader == null:
		push_error("Universal sticker preloader not found")
		return
	
	# Copy everything from the preloader into the dictionary
	for key in tgt_preloader.get_resource_list():
		sticker_dict[key] = tgt_preloader.get_resource(key)

func add_group_stickers(group_id: String, is_large: bool, sticker_dict: Dictionary) -> void:
	var size_suffix = "_Large" if is_large else "_Small"
	var tgt_preloader: ResourcePreloader = get_node_or_null(group_id + size_suffix)
	
	if tgt_preloader == null:
		push_error("Preloader not found: %s" % (group_id + size_suffix))
		return
	
	# Copy everything from the preloader into the dictionary
	for key in tgt_preloader.get_resource_list():
		sticker_dict[key] = tgt_preloader.get_resource(key)
