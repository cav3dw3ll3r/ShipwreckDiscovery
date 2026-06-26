extends Resource
class_name Spotlight_Target

@export var scanner_hologram:PackedScene
@export var near_mesh:Mesh
@export var mid_mesh:Mesh
@export var far_mesh:Mesh
# Per-LOD materials for batching (Quest): when set, chunks use these instead of mesh-built-in. Prefer shared .tres (e.g. BigDawg_Near_Shared).
@export var near_material: Material
@export var mid_material: Material
@export var far_material: Material
@export var shared_material: Material
@export var shape:Shape3D
@export var shape_offset:Vector3
@export var shape_scale:Vector3=Vector3.ONE
@export var shape_rotation:Vector3 = Vector3.ZERO
@export var damage:int = 10
@export var scannable:Scannable
