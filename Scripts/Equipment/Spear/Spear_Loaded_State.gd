extends SpearSingleHoldState
class_name SpearLoadedState

var _zookeeper_instance: Node3D = null
var _zookeeper_pickup: XRToolsFunctionPickup = null
var _allow_zookeeper_release: bool = false


func enter(_spear: RevisedSpearPickable, _params = {}):
	super.enter(_spear, _params)
	if _spear == null or not is_instance_valid(_spear):
		return

	_spear.secondary_grab.enabled = false

	var pickup := _spear.get_off_hand_pickup()
	_zookeeper_pickup = pickup
	_destroy_off_hand_holding_other_than_spear(_spear, pickup)

	if _spear.zookeeper_scene != null and pickup != null:
		var inst := _spear.zookeeper_scene.instantiate() as Node3D
		if inst != null:
			var scene_root := _spear.get_tree().current_scene
			if scene_root:
				scene_root.add_child(inst)
			else:
				_spear.add_child(inst)
			inst.global_transform = pickup.global_transform
			_zookeeper_instance = inst
			pickup._pick_up_object(inst)
			if inst is ZookeeperPickable:
				var zk := inst as ZookeeperPickable
				zk.bind_spear(_spear)
				zk.show_lite_hand_for_pickup(pickup)
			if inst is XRToolsPickable:
				(inst as XRToolsPickable).released.connect(_on_zookeeper_released)


func _on_zookeeper_released(_pickable: XRToolsPickable, by: Node3D) -> void:
	if _allow_zookeeper_release:
		return
	if not is_instance_valid(_zookeeper_instance):
		return
	if not is_instance_valid(_zookeeper_pickup):
		return
	if by != _zookeeper_pickup:
		return
	call_deferred("_regrab_zookeeper_after_blocked_release")


func _regrab_zookeeper_after_blocked_release() -> void:
	if _allow_zookeeper_release:
		return
	if not is_instance_valid(_zookeeper_instance):
		return
	if not is_instance_valid(_zookeeper_pickup):
		return
	if _zookeeper_pickup.picked_up_object != _zookeeper_instance:
		_zookeeper_pickup._pick_up_object(_zookeeper_instance)


func _destroy_off_hand_holding_other_than_spear(p_spear: RevisedSpearPickable, pickup: XRToolsFunctionPickup) -> void:
	if pickup == null:
		return
	var prev := pickup.picked_up_object
	if not is_instance_valid(prev) or prev == p_spear:
		return
	pickup.drop_object()
	if is_instance_valid(prev):
		prev.queue_free()


func exit(next_state: SpearState = null):
	var s := spear
	var keep_zookeeper_active := next_state is SpearCapturedState

	if keep_zookeeper_active:
		_allow_zookeeper_release = false
		super.exit(next_state)
		return

	_allow_zookeeper_release = true

	if is_instance_valid(_zookeeper_instance):
		var z_inst := _zookeeper_instance
		var xf := z_inst.global_transform

		if s != null and is_instance_valid(s):
			if s.loaded_state_exploding_dummy_scene != null:
				var scene_root := s.get_tree().current_scene
				if scene_root:
					var dummy := s.loaded_state_exploding_dummy_scene.instantiate() as Node3D
					if dummy != null:
						scene_root.add_child(dummy)
						dummy.global_transform = xf
						RevisedSpearPickable.reparent_spear_trophies_zk_to_dummy(z_inst, dummy, s)

			var pickup := s.get_off_hand_pickup()
			if pickup != null and pickup.picked_up_object == z_inst:
				##(z_inst as ZookeeperPickable).allow_forced_release()
				pickup.drop_object()

		if is_instance_valid(z_inst):
			z_inst.queue_free()
		_zookeeper_instance = null
		_zookeeper_pickup = null

	if s != null and is_instance_valid(s):
		s.secondary_grab.enabled = true

	super.exit(next_state)
