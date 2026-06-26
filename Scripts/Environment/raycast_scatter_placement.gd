@tool
extends EditorScript

var scenes: Array[PackedScene] = [load("res://Meshes/Fish/Destin/Lionfish/lionfish_proxy.tscn")]
var count: int = 50

var area_center: Vector3 = Vector3(0,0,0)
var area_size: Vector2 = Vector2(20,20)

var ray_height: float = 50.0
var max_distance: float = 100.0

# Layer 16 = bit 15
const LAYER_16_MASK := 1 << 15


func _run():
	if scenes.is_empty():
		push_warning("No PackedScenes assigned.")
		return

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		push_warning("No scene root.")
		return

	var center := area_center
	var instant_dive := root.get_tree().get_nodes_in_group("InstantDive")
	if not instant_dive.is_empty():
		center = instant_dive[0].global_position
		center.y = 0.0

	var space_state = root.get_world_3d().direct_space_state

	for i in count:
		var scene = scenes.pick_random()
		if not scene:
			continue

		var x := randf_range(-area_size.x * 0.5, area_size.x * 0.5)
		var z := randf_range(-area_size.y * 0.5, area_size.y * 0.5)

		var ray_origin := center + Vector3(x, ray_height, z)
		var ray_end := ray_origin + Vector3.DOWN * max_distance

		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_end,
			LAYER_16_MASK
		)
		query.collide_with_areas = false

		var hit = space_state.intersect_ray(query)

		if hit.is_empty():
			continue

		var instance = scene.instantiate()
		instance.global_position = hit.position
		instance.rotation.y = randf_range(0.,360.)
		root.add_child(instance)
		instance.owner = root  # VERY important for editor visibility
