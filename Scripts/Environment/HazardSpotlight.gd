extends Area3D
class_name HazardSpotlight

## The group name of entities that provide spotlight targets
@export var group_name: String = "hazard"
## Maximum distance of the spotlight beam
@export var max_distance: float = 5.0
## How often (in seconds) the spotlight can damage the same target
@export var damage_cooldown: float = 0.5

@onready var player: Node3D = get_tree().get_first_node_in_group("Player")

# Tracks active cooldowns to prevent frame-perfect multi-hits: { Node3D: float }
var active_cooldowns: Dictionary = {}

func _process_cooldowns(delta: float) -> void:
	var expired_targets: Array[Node3D] = []
	
	for target in active_cooldowns:
		active_cooldowns[target] -= delta
		if active_cooldowns[target] <= 0.0:
			expired_targets.append(target)
			
	for target in expired_targets:
		active_cooldowns.erase(target)

func _cast_spotlights() -> void:
	# Failsafe if the player hasn't loaded or was destroyed
	if not is_instance_valid(player):
		return

	# Grab the direct space state for our pure math queries
	var space_state = get_world_3d().direct_space_state

	for entity in get_tree().get_nodes_in_group(group_name):
		if not entity.has_method("get_spotlight"):
			
			continue

		var st = entity.get_spotlight()
		if st == null or not st.shape: 
			continue

		for xform in entity.get_targetable_transforms():
			var dist = xform.origin.distance_to(player.global_position)
			
			# Broad-phase check: Ignore hazards too far away
			if dist > max_distance:
				continue
			
			# Construct the exact transform for this specific hazard
			var target_xf: Transform3D = xform
			target_xf = target_xf.translated_local(st.shape_offset)
			var rot: Vector3 = st.shape_rotation
			if rot != Vector3.ZERO:
				var rot_rad: Vector3 = rot * (PI / 180.0)
				target_xf.basis = target_xf.basis * Basis.from_euler(rot_rad)
			target_xf.basis = target_xf.basis.scaled(st.shape_scale)

			# Construct the physical shape query
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = st.shape
			query.transform = target_xf
			
			# Optional but highly recommended for VR: Set this mask to ONLY check the player's layer
			# query.collision_mask = 2 

			# Cast the shape into the world
			var results = space_state.intersect_shape(query)
			
			# Process hits
			for result in results:
				var collider = result["collider"]
				
				if is_instance_valid(collider) and collider.has_method("take_damage"):
					if not active_cooldowns.has(collider):
						collider.take_damage(10, 10)
						active_cooldowns[collider] = damage_cooldown
