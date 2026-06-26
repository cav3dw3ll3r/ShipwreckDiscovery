@tool
extends Node3D
class_name SpotlightTargetAssembler
# For each mesh index (X_X_X from end of node names), creates one Spotlight_Target and
# builds a prefab scene of Node3D chunks (mesh + spotlight target) at the same positions.
# Run from editor with Run = true.

var _run: bool = false
@export var run: bool = false:
	get: return _run
	set(value): _on_run_set(value)
@export var wreck_name: String = "BigDawg"
@export_dir var spotlight_targets_dir: String = "res://Resources/Scannable/Spotlight_Targets/Wrecks/"
@export_dir var output_scene_path: String = "res://Prefabs/Wrecks/BigDawg/big_dawg_chunks.tscn"
@export_dir var assembled_scene_path: String = "res://Prefabs/Wrecks/BigDawg/BigDawg_assembled.tscn"
# Optional: assign shared materials per LOD so generated Spotlight_Targets use one material per LOD (Quest batching).
@export_file("*res") var shared_material_path: String = "res://Prefabs/Wrecks/BigDawg/BigDawg_Near_Shared.tres"
@export var wrapper_prefabs: Array[PackedScene] = []

const CHUNK_SCRIPT_PATH := "res://Scripts/Environment/WreckChunkClimbable.gd"

var _collisions_node: Node3D
var _near_node: Node3D
var _mid_node: Node3D
var _far_node: Node3D

func _get_configuration_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if not _has_expected_children():
		w.append("Expected direct children: Collisions, Far, Mid, Near (instanced .glb).")
	return w

func _has_expected_children() -> bool:
	return get_node_or_null("Collisions") != null \
		and get_node_or_null("Far") != null \
		and get_node_or_null("Mid") != null \
		and get_node_or_null("Near") != null

func _on_run_set(value: bool) -> void:
	_run = value
	if value:
		_assemble()
		_run = false
		notify_property_list_changed()

# --- Index: pull X_X_X from end of name (last 3 underscore-separated segments) ---

static func _index_from_name(node_name: String) -> String:
	var parts := node_name.split("_")
	if parts.size() < 3:
		return ""
	return "_".join(parts.slice(-3, parts.size()))

# Strip -col, -colonly, -convcol, -convcolonly so "Mesh_0_0_0-colonly" can yield index
static func _index_from_name_allow_suffix(node_name: String) -> String:
	var n := node_name
	for suffix in ["-colonly", "-convcolonly", "-col", "-convcol"]:
		n = n.replace(suffix, "")
	return _index_from_name(n)

# --- Collect mesh instances by index (index -> { node, mesh }) ---

func _collect_mesh_by_index(root: Node) -> Dictionary:
	var out: Dictionary = {}
	if root == null:
		return out
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root
		if mi.mesh is Mesh:
			var idx := _index_from_name(mi.name)
			if idx != "":
				out[idx] = { "node": mi, "mesh": mi.mesh }
	for c in root.get_children():
		var sub := _collect_mesh_by_index(c)
		for k in sub:
			out[k] = sub[k]
	return out

# --- Collect all mesh instances in depth-first order (for Far/Mid when names lack index) ---

func _collect_mesh_instances_ordered(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root
		if mi.mesh is Mesh:
			out.append({ "node": mi, "mesh": mi.mesh })
	for c in root.get_children():
		out.append_array(_collect_mesh_instances_ordered(c))
	return out

# --- Collect collision shapes by index (index -> { node, shape }); use parent name if shape has no index ---

func _collect_collision_by_index(root: Node) -> Dictionary:
	var out: Dictionary = {}
	if root == null:
		return out
	if root is CollisionShape3D:
		var cs: CollisionShape3D = root
		if cs.shape != null:
			var idx := _index_from_name(cs.name)
			if idx == "":
				var p := cs.get_parent()
				while p != null and idx == "":
					idx = _index_from_name_allow_suffix(p.name)
					p = p.get_parent()
			if idx != "":
				out[idx] = { "node": cs, "shape": cs.shape }
	for c in root.get_children():
		var sub := _collect_collision_by_index(c)
		for k in sub:
			out[k] = sub[k]
	return out

# --- Collect all collision shape nodes in depth-first order (fallback when names lack index) ---

func _collect_collision_shapes_ordered(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	if root is CollisionShape3D:
		var cs: CollisionShape3D = root
		if cs.shape != null:
			out.append({ "node": cs, "shape": cs.shape })
	for c in root.get_children():
		out.append_array(_collect_collision_shapes_ordered(c))
	return out

# --- When Collisions.glb has no CollisionShape3D, build shape from MeshInstance3D (order-based) ---

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for c in node.get_children():
		_set_owner_recursive(c, owner_node)

# Subtrees we never search for AIBlocking (imported LOD/collision GLBs — huge, never contain AIBlocking).
const _AI_BLOCKING_SKIP_SUBTREES: Array[String] = ["Collisions", "Far", "Mid", "Near"]

static func _is_ai_blocking_name(node_name: String) -> bool:
	if node_name == "AIBlocking":
		return true
	return node_name.begins_with("AIBlocking")

func _collect_ai_blocking_nodes(root: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	_collect_ai_blocking_nodes_impl(root, out)
	return out

func _collect_ai_blocking_nodes_impl(n: Node, out: Array[Node3D]) -> void:
	for c in n.get_children():
		if (c.name as String) in _AI_BLOCKING_SKIP_SUBTREES:
			continue
		if c is Node3D and _is_ai_blocking_name(String(c.name)):
			out.append(c as Node3D)
		_collect_ai_blocking_nodes_impl(c, out)

func _collect_collision_from_meshes_ordered(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root
		if mi.mesh is Mesh:
			var shape: Shape3D = (mi.mesh as Mesh).create_trimesh_shape()
			if shape != null:
				out.append({ "node": mi, "shape": shape })
	for c in root.get_children():
		out.append_array(_collect_collision_from_meshes_ordered(c))
	return out

func _assemble() -> void:
	_collisions_node = get_node_or_null("Collisions")
	_near_node = get_node_or_null("Near")
	_mid_node = get_node_or_null("Mid")
	_far_node = get_node_or_null("Far")

	if not _collisions_node or not _near_node or not _mid_node or not _far_node:
		push_error("SpotlightTargetAssembler: Missing Collisions, Far, Mid, or Near child.")
		return

	var near_by := _collect_mesh_by_index(_near_node)
	var mid_by := _collect_mesh_by_index(_mid_node)
	var far_by := _collect_mesh_by_index(_far_node)
	var coll_by := _collect_collision_by_index(_collisions_node)

	# Order-based fallback when Far/Collisions nodes don't have X_X_X in name
	var far_ordered := _collect_mesh_instances_ordered(_far_node)
	var coll_ordered := _collect_collision_shapes_ordered(_collisions_node)
	# When Collisions.glb has no CollisionShape3D (physics not generated on import), build shape from meshes
	var coll_from_meshes_ordered := _collect_collision_from_meshes_ordered(_collisions_node)

	var all_indices: Array[String] = []
	var seen := {}
	for k in near_by: if k not in seen: all_indices.append(k); seen[k] = true
	for k in mid_by:  if k not in seen: all_indices.append(k); seen[k] = true
	for k in far_by:  if k not in seen: all_indices.append(k); seen[k] = true
	for k in coll_by: if k not in seen: all_indices.append(k); seen[k] = true
	all_indices.sort()

	if all_indices.is_empty():
		push_error("SpotlightTargetAssembler: No nodes with X_X_X index suffix found in Collisions/Far/Mid/Near.")
		return

	var base_dir := spotlight_targets_dir.strip_edges()
	if not base_dir.ends_with("/"):
		base_dir += "/"
	var da := DirAccess.open("res://")
	if da == null:
		push_error("SpotlightTargetAssembler: Could not open res:// for directory creation.")
		return
	var rel_base := base_dir.trim_prefix("res://").trim_prefix("/")
	if da.make_dir_recursive(rel_base) != OK:
		push_error("SpotlightTargetAssembler: Could not create directory: " + base_dir)
		return

	var out_scene_path := output_scene_path.strip_edges()
	if out_scene_path.is_empty():
		out_scene_path = "res://Prefabs/Wrecks/%s/big_dawg_chunks.tscn" % wreck_name
	var out_scene_dir := out_scene_path.get_base_dir()
	var rel_scene := out_scene_dir.trim_prefix("res://").trim_prefix("/")
	if da.make_dir_recursive(rel_scene) != OK:
		push_error("SpotlightTargetAssembler: Could not create directory: " + out_scene_dir)
		return

	var assembled_path := assembled_scene_path.strip_edges()
	if assembled_path.is_empty():
		assembled_path = "res://Prefabs/Wrecks/%s/BigDawg_assembled.tscn" % wreck_name
	var assembled_dir := assembled_path.get_base_dir()
	var rel_assembled := assembled_dir.trim_prefix("res://").trim_prefix("/")
	if da.make_dir_recursive(rel_assembled) != OK:
		push_error("SpotlightTargetAssembler: Could not create directory: " + assembled_dir)
		return

	var chunk_script := load(CHUNK_SCRIPT_PATH) as GDScript
	if chunk_script == null:
		push_error("SpotlightTargetAssembler: Missing script: " + CHUNK_SCRIPT_PATH)
		return

	var root_node := Node3D.new()
	root_node.name = wreck_name + "Assembled"

	for i in all_indices.size():
		var idx: String = all_indices[i]
		var near_data = near_by.get(idx)
		var mid_data = mid_by.get(idx)
		var far_data = far_by.get(idx)
		var coll_data = coll_by.get(idx)
		# Fallback: match Far and Collisions by position when name index is missing
		if far_data == null and i < far_ordered.size():
			far_data = far_ordered[i]
		if coll_data == null and i < coll_ordered.size():
			coll_data = coll_ordered[i]
		if coll_data == null and i < coll_from_meshes_ordered.size():
			coll_data = coll_from_meshes_ordered[i]

		var near_mesh: Mesh = near_data["mesh"] if near_data else null
		var mid_mesh: Mesh = mid_data["mesh"] if mid_data else null
		var far_mesh: Mesh = far_data["mesh"] if far_data else null
		var shape: Shape3D = coll_data["shape"] if coll_data else null

		# Skip indices with no collision shape to avoid shapeless chunks
		if shape == null:
			continue

		# Shared material: use Near LOD surface 0 (override or mesh built-in) so all LODs use same material
		var shared_mat: Material = null
		if near_data and near_data["node"] is MeshInstance3D:
			shared_mat = (near_data["node"] as MeshInstance3D).get_surface_override_material(0)
		if shared_mat == null and near_mesh != null and near_mesh.get_surface_count() > 0:
			shared_mat = near_mesh.surface_get_material(0)

		# Build Spotlight_Target for this index
		var st := Spotlight_Target.new()
		st.near_mesh = near_mesh
		st.mid_mesh = mid_mesh
		st.far_mesh = far_mesh
		st.shared_material = shared_mat
		# Per-LOD shared materials for Quest batching (WreckChunkClimbable applies the one matching current mesh)
		var near_mat_path := shared_material_path.strip_edges()
		var mid_mat_path := shared_material_path.strip_edges()
		var far_mat_path := shared_material_path.strip_edges()
		if near_mat_path != "":
			st.near_material = load(near_mat_path) as Material
		if mid_mat_path != "":
			st.mid_material = load(mid_mat_path) as Material
		if far_mat_path != "":
			st.far_material = load(far_mat_path) as Material
		st.shape = shape
		if coll_data:
			var coll_node: Node3D = coll_data["node"] as Node3D
			if coll_node != null:
				st.shape_offset = coll_node.position
				st.shape_scale = coll_node.scale
				st.shape_rotation = coll_node.rotation_degrees

		var st_path := base_dir + wreck_name + "_" + idx + ".tres"
		if ResourceSaver.save(st, st_path) != OK:
			push_error("SpotlightTargetAssembler: Failed to save Spotlight_Target: " + st_path)
			continue

		# Transform: prefer Near mesh position, then Mid, Far, then Collision
		var source_node: Node3D = null
		if near_data: source_node = near_data["node"] as Node3D
		elif mid_data: source_node = mid_data["node"] as Node3D
		elif far_data: source_node = far_data["node"] as Node3D
		elif coll_data: source_node = coll_data["node"] as Node3D
		if source_node == null:
			continue

		var chunk := Node3D.new()
		chunk.name = "Chunk_" + idx.replace(" ", "_")
		# Same world position as source mesh/collision (root will be at origin when instanced)
		chunk.transform = source_node.global_transform

		var mi := MeshInstance3D.new()
		mi.mesh = near_mesh if near_mesh else mid_mesh if mid_mesh else far_mesh
		chunk.add_child(mi)
		mi.owner = root_node

		# No CollisionShape3D on the chunk: SolidClimbableSpotlight uses Spotlight_Target.shape
		# in its own shape pool for grab collision, so we avoid duplicate collision.

		chunk.set_script(chunk_script)
		var loaded_st := load(st_path) as Spotlight_Target
		if loaded_st:
			chunk.set("spotlight_target", loaded_st)

		root_node.add_child(chunk)
		chunk.owner = root_node

	var packed_chunks := PackedScene.new()
	if packed_chunks.pack(root_node) != OK:
		push_error("SpotlightTargetAssembler: Failed to pack scene.")
		root_node.queue_free()
		return

	if ResourceSaver.save(packed_chunks, out_scene_path) != OK:
		push_error("SpotlightTargetAssembler: Failed to save scene: " + out_scene_path)
		root_node.queue_free()
		return

	var assembled_root := Node3D.new()
	assembled_root.name = wreck_name + "Assembled"

	for i in wrapper_prefabs.size():
		var prefab := wrapper_prefabs[i]
		if prefab == null:
			continue
		var inst := prefab.instantiate()
		if inst == null:
			continue
		assembled_root.add_child(inst)
		# Optional placement hints: if a direct child node named `hint_<i>` exists,
		# place the instantiated wrapper prefab to match that hint's global transform.
		var hint := get_node_or_null("hint_%d" % i)
		if hint is Node3D and inst is Node3D:
			(inst as Node3D).global_transform = (hint as Node3D).global_transform
		_set_owner_recursive(inst, assembled_root)

	var chunks_scene := load(out_scene_path) as PackedScene
	if chunks_scene == null:
		push_error("SpotlightTargetAssembler: Could not load chunks scene for assembled output: " + out_scene_path)
	else:
		var chunks_root := chunks_scene.instantiate()
		assembled_root.add_child(chunks_root)
		chunks_root.owner = assembled_root
		_set_owner_recursive(chunks_root, assembled_root)

	for src in _collect_ai_blocking_nodes(self):
		var dup := src.duplicate()
		assembled_root.add_child(dup)
		if dup is Node3D:
			(dup as Node3D).global_transform = (src as Node3D).global_transform

	_set_owner_recursive(assembled_root, assembled_root)

	var packed_assembled := PackedScene.new()
	if packed_assembled.pack(assembled_root) != OK:
		push_error("SpotlightTargetAssembler: Failed to pack assembled wrapper scene.")
		root_node.queue_free()
		assembled_root.queue_free()
		return

	if ResourceSaver.save(packed_assembled, assembled_path) != OK:
		push_error("SpotlightTargetAssembler: Failed to save assembled wrapper scene: " + assembled_path)

	root_node.queue_free()
	assembled_root.queue_free()
