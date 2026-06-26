@tool
extends Node3D

@export var coral_type: CoralData.CoralType

var _starting_biomass: float = 0.0
@export_range(0.0, 100.0) var starting_biomass: float = 1.0:
	get:
		return _starting_biomass
	set(value):
		_starting_biomass = value
		_apply_biomass_visual()

@export var starting_resilience: float = 1.0

@export_node_path("MeshInstance3D") var baby_mesh_instance_path: NodePath = ^"BabyMesh"
@export_node_path("MeshInstance3D") var growing_mesh_instance_path: NodePath = ^"GrowingMesh"
@export_node_path("MeshInstance3D") var pristine_mesh_instance_path: NodePath = ^"PristineMesh"

@export_group("Biomass Meshes")
var _baby_coral_mesh: Mesh
@export var baby_coral_mesh: Mesh:
	get:
		return _baby_coral_mesh
	set(value):
		_baby_coral_mesh = value
		_apply_biomass_visual()

var _growing_coral_mesh: Mesh
@export var growing_coral_mesh: Mesh:
	get:
		return _growing_coral_mesh
	set(value):
		_growing_coral_mesh = value
		_apply_biomass_visual()

var _pristine_coral_mesh: Mesh
@export var pristine_coral_mesh: Mesh:
	get:
		return _pristine_coral_mesh
	set(value):
		_pristine_coral_mesh = value
		_apply_biomass_visual()

@export_group("Biomass Materials")
var _baby_coral_material: Material
@export var baby_coral_material: Material:
	get:
		return _baby_coral_material
	set(value):
		_baby_coral_material = value
		_apply_biomass_visual()

var _growing_coral_material: Material
@export var growing_coral_material: Material:
	get:
		return _growing_coral_material
	set(value):
		_growing_coral_material = value
		_apply_biomass_visual()

var _pristine_coral_material: Material
@export var pristine_coral_material: Material:
	get:
		return _pristine_coral_material
	set(value):
		_pristine_coral_material = value
		_apply_biomass_visual()


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_apply_biomass_visual()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _get_mesh_instance(baby_mesh_instance_path) == null:
		warnings.append("Expected a child MeshInstance3D at baby_mesh_instance_path.")
	if _get_mesh_instance(growing_mesh_instance_path) == null:
		warnings.append("Expected a child MeshInstance3D at growing_mesh_instance_path.")
	if _get_mesh_instance(pristine_mesh_instance_path) == null:
		warnings.append("Expected a child MeshInstance3D at pristine_mesh_instance_path.")
	return warnings


func _get_mesh_instance(path: NodePath) -> MeshInstance3D:
	if path.is_empty():
		return null
	return get_node_or_null(path) as MeshInstance3D


func _stage_from_mesh_instance(mesh_instance: MeshInstance3D) -> CoralStageData:
	var stage := CoralStageData.new()
	if mesh_instance == null:
		return stage

	stage.local_position = mesh_instance.position
	stage.rotation_y = mesh_instance.rotation.y
	var scale := mesh_instance.scale
	stage.scale_seed = (scale.x + scale.y + scale.z) / 3.0
	return stage


func _configure_stage_mesh(
	mesh_instance: MeshInstance3D,
	mesh: Mesh,
	material: Material,
	visible: bool
) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.visible = visible


func _apply_biomass_visual() -> void:
	var show_baby := _starting_biomass < 30.0
	var show_growing := _starting_biomass >= 30.0 and _starting_biomass < 85.0
	var show_pristine := _starting_biomass >= 85.0

	_configure_stage_mesh(
		_get_mesh_instance(baby_mesh_instance_path),
		_baby_coral_mesh,
		_baby_coral_material,
		show_baby
	)
	_configure_stage_mesh(
		_get_mesh_instance(growing_mesh_instance_path),
		_growing_coral_mesh,
		_growing_coral_material,
		show_growing
	)
	_configure_stage_mesh(
		_get_mesh_instance(pristine_mesh_instance_path),
		_pristine_coral_mesh,
		_pristine_coral_material,
		show_pristine
	)


func bake() -> CoralData:
	var coral_data := CoralData.new()
	coral_data.global_position = global_position
	coral_data.baby_stage = _stage_from_mesh_instance(_get_mesh_instance(baby_mesh_instance_path))
	coral_data.growing_stage = _stage_from_mesh_instance(_get_mesh_instance(growing_mesh_instance_path))
	coral_data.pristine_stage = _stage_from_mesh_instance(_get_mesh_instance(pristine_mesh_instance_path))
	coral_data.biomass = _starting_biomass
	coral_data.resilience = starting_resilience
	coral_data.type = coral_type
	return coral_data
