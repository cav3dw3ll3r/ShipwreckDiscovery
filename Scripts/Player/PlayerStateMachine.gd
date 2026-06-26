class_name PlayerStateMachine
extends StateMachine

var initialState = preload("res://Scripts/Player/WalkingState.gd")
var climbingState = preload("res://Scripts/Player/ClimbingState.gd")
var staggerState = preload("res://Scripts/Player/StaggerState.gd")
var respawnState = preload("res://Scripts/Player/RespawnState.gd")

@export_group("Controls")
@export var walkingControlScheme: Array[XRToolsMovementProvider] = []
@export var swimmingControlScheme: Array[XRToolsMovementProvider] = []
@export var submergedControlScheme: Array[XRToolsMovementProvider] = []
@export var rightClimbingControlScheme: Array[XRToolsMovementProvider] = []
@export var leftClimbingControlScheme: Array[XRToolsMovementProvider] = []

@export_group("Sounds")
@export var leftGrabSound:AudioStreamPlayer3D
@export var rightGrabSound:AudioStreamPlayer3D
@export var damageSound:AudioStreamPlayer3D
@export var breathSound:AudioStreamPlayer3D

@export_group("Other")
@export var vignette:VignetteController
@export var eyelids:Progress_Animator
@export var eyelidDamageImpulse:EyelidDamageImpulse
@export var breathBubbles:GPUParticles3D

@export var direct_movement:XRToolsMovementProvider
@export var turn_movement:XRToolsMovementTurn

@onready var cameraNode = $"../XRCamera3D"
@onready var bodyNode:XRToolsPlayerBody = $"../XRToolsPlayerBody" 
@onready var _left_controller := XRHelpers.get_left_controller(self)
@onready var _right_controller := XRHelpers.get_right_controller(self)

@onready var game_settings:GameSettings = get_tree().get_first_node_in_group("GameSettings")
var waves
var currentVelocity = Vector3(0,0,0)
var previousHeadPos = Vector3(0,0,0)
var previous_state
var maxHealth = 100
var maxAir = 100.0
var remainingHealth:float = 100.0
var remainingAir:float = 100.0
# Whether the player just grabbed with their left hand (else right)
var grabbedLeft = false
var staggered:bool = false
var stagger_vector = Vector3.ZERO
var _hoop_pass_boost: Vector3 = Vector3.ZERO
var _hoop_pass_boost_decay: float = 0.65
var velocity_history = [] # Array of { "age": float, "vel": float }
var rolling_avg_vertical_velocity = 0.0
var barotrauma_risk_accumulator = 0
var right_stick_override:bool=false

const stagger_push_multiplier = 0.5

signal damage_event
signal air_event

func switch_state(state):
	super(state)

func set_speed(new_speed):
	direct_movement.max_speed = new_speed
	pass

func set_turn_mode(use_snap:bool):
	if use_snap:
		turn_movement.turn_mode = turn_movement.TurnMode.SNAP
	else:
		turn_movement.turn_mode = turn_movement.TurnMode.SMOOTH

func try_regenerate():
	if "extreme_healing" in game_settings.active_powers:
		remainingHealth+=1
		remainingHealth = clampf(remainingHealth,0,maxHealth)
		damage_event.emit()

func take_damage(amount,stagger,sender_global_pos):
	if eyelidDamageImpulse:
		eyelidDamageImpulse.play_damage_pulse(1.0)
	if(staggered):
		return
	staggered = true
	remainingHealth-=amount
	stagger_vector = ((global_position-sender_global_pos).normalized())*stagger_push_multiplier
	dual_haptic_pulse(0.4,0.2)
	damageSound.play()
	damage_event.emit()
	previous_state = current_state
	if(remainingHealth<=0):
		respawn()
	else:
		switch_state(staggerState.new())

func dual_haptic_pulse(amplitude,duration):
	_left_controller.trigger_haptic_pulse("haptic",0.0,amplitude,duration,0.0)
	_right_controller.trigger_haptic_pulse("haptic",0.0,amplitude,duration,0.0)

func respawn():
	switch_state(respawnState.new())

func reset_position():
	var spawnPoint:Node3D = get_tree().get_first_node_in_group("Respawn")
	bodyNode.teleport(spawnPoint.global_transform)

func lose_air(amount):
	if(remainingAir>=amount):
		remainingAir-=amount
	else:
		take_damage(int(amount*25),0,self)
	#TODO: Emit breath bubbles whenever air is deducted
	breathBubbles.emitting=true
	breathSound.play()
	air_event.emit()

func set_gravity(boolVal):
	bodyNode.is_using_gravity=boolVal

func set_height_override(override:float):
	bodyNode.override_player_height("generic",override)

func apply_hoop_pass_boost(world_direction: Vector3, peak_speed: float, decay: float) -> void:
	_hoop_pass_boost = world_direction.normalized() * peak_speed
	_hoop_pass_boost_decay = maxf(decay, 0.01)
	dual_haptic_pulse(0.35, 0.12)


func _physics_process(delta: float) -> void:
	var current_pos = cameraNode.global_transform.origin
	currentVelocity = (previousHeadPos - current_pos) / delta
	previousHeadPos = current_pos
	_apply_hoop_pass_boost(delta)
	var vertical_velocity = currentVelocity.y
	for entry in velocity_history:
		entry["age"] += delta
	velocity_history.append({ "age": 0.0, "vel": vertical_velocity })
	while velocity_history.size() > 0 and velocity_history[0]["age"] > 0.5:
		velocity_history.pop_front()
	if velocity_history.size() > 0:
		var sum = 0.0
		for entry in velocity_history:
			sum += entry["vel"]
		rolling_avg_vertical_velocity = sum / velocity_history.size()
	else:
		rolling_avg_vertical_velocity = 0.0


func _apply_hoop_pass_boost(delta: float) -> void:
	if _hoop_pass_boost.length_squared() < 0.01:
		_hoop_pass_boost = Vector3.ZERO
		return
	bodyNode.velocity += _hoop_pass_boost * delta
	_hoop_pass_boost *= exp(-_hoop_pass_boost_decay * delta)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Post_Spawn.timeout.connect(_post_spawn)
	$Post_Spawn.start(1.)
	clear_all_controls()
	waves = get_tree().get_first_node_in_group("Waves")
	switch_state(initialState.new())
	call_deferred("connect_to_power_list")
	vignette.set_on()
	pass # Replace with function body.

func vignette_on(is_on):
	if is_on:
		vignette.set_on()
	else:
		vignette.set_off()

func set_vignette_strength(strength:float):
	vignette.set_base_strength(strength)

func vignette_impulse(strength:float):
	vignette.impulse(strength)

func _post_spawn():
	print("Doing the thing")
	eyelids_open()

func eyelids_open() -> void:
	if eyelids:
		eyelids.set_on()

func eyelids_close() -> void:
	if eyelids:
		eyelids.set_off()

## Closes eyelids and invokes [param callback] when the close animation finishes (or immediately if eyelids is null).
func eyelids_close_and_call(callback: Callable) -> void:
	if not eyelids:
		callback.call()
		return
	eyelids.done.connect(callback, CONNECT_ONE_SHOT)
	eyelids.set_off()

func connect_to_power_list():
	game_settings = get_tree().get_first_node_in_group("GameSettings")
	if not game_settings: return
	game_settings.on_powers_update.connect(apply_powers)
	var use_snap_turn = game_settings.use_snap_turn
	if use_snap_turn:
		turn_movement.turn_mode=turn_movement.TurnMode.SNAP
	else:
		turn_movement.turn_mode=turn_movement.TurnMode.SMOOTH
	apply_powers()

func apply_powers():
	if "extra_air" in game_settings.active_powers:
		maxAir = 150
	remainingAir = maxAir
	
	if "health_nut" in game_settings.active_powers:
		maxHealth = 150
	remainingHealth = maxHealth
	
	if "extreme_healing" in game_settings.active_powers:
		$Timer.start()
	
	damage_event.emit()
	air_event.emit()

func is_under_water() -> bool:
	return cameraNode.global_transform.origin.y <= get_water_height_at_pos()

func get_water_height_at_pos() -> float:
	if(waves):
		return waves.getWaveHeight(global_position.x,global_position.z)
	else:
		return 0.0

# Returns the depth of the player's head under the water
func get_depth_under_water() -> float:
	return get_water_height_at_pos()-cameraNode.global_position.y

func clear_all_controls():
	set_controls(walkingControlScheme,false)
	set_controls(swimmingControlScheme,false)
	set_controls(submergedControlScheme,false)
	set_controls(leftClimbingControlScheme,false)
	set_controls(rightClimbingControlScheme,false)

func enable_walk():
	set_controls(walkingControlScheme,true)

func enable_swim():
	set_controls(swimmingControlScheme,true)

func enable_submerged():
	set_controls(submergedControlScheme,true)

func enable_climb(isLeftSide:bool):
	if(isLeftSide):
		set_controls(leftClimbingControlScheme,true)
	else:
		set_controls(rightClimbingControlScheme,true)

func set_controls(control_scheme,isActive):
	for node in control_scheme:
		node.enabled=isActive

func _debug_enabled_providers() -> Array:
	var result: Array = []
	for n in get_tree().get_nodes_in_group("movement_providers"):
		if "enabled" in n and n.enabled:
			result.append(n.name)
	return result

func on_left_climb_trigger(_unused):
	print("[CLIMB] LEFT TRIGGER: state_before=", current_state, " grabbedLeft(before)=", grabbedLeft)
	grabbedLeft=true
	leftGrabSound.play()
	_left_controller.trigger_haptic_pulse("haptic",0.0,0.2,0.1,0.0)
	print("[CLIMB] LEFT TRIGGER: state_after=", current_state, " grabbedLeft(after)=", grabbedLeft, " enabled_providers=", _debug_enabled_providers())

func on_right_climb_trigger(_unused):
	print("[CLIMB] RIGHT TRIGGER: state_before=", current_state, " grabbedLeft(before)=", grabbedLeft)
	grabbedLeft=false
	rightGrabSound.play()
	_right_controller.trigger_haptic_pulse("haptic",0.0,0.2,0.1,0.0)
	print("[CLIMB] RIGHT TRIGGER: state_after=", current_state, " grabbedLeft(after)=", grabbedLeft, " enabled_providers=", _debug_enabled_providers())

func on_left_letgo():
	print("[CLIMB] LEFT LETGO: state_before=", current_state, " grabbedLeft=", grabbedLeft, " enabled_providers=", _debug_enabled_providers())
	_left_controller.trigger_haptic_pulse("haptic",0.0,0.1,0.1,0.0)
	# has_dropped fires for every pickable (e.g. spear). Only exit climb when we are actually climbing.
	if current_state == null or current_state.get_script() != climbingState:
		print("[CLIMB] LEFT LETGO: state_after=", current_state, " enabled_providers=", _debug_enabled_providers())
		return
	if(grabbedLeft):
		set_gravity(true)
		switch_state(initialState.new())
	print("[CLIMB] LEFT LETGO: state_after=", current_state, " enabled_providers=", _debug_enabled_providers())

func on_right_letgo():
	print("[CLIMB] RIGHT LETGO: state_before=", current_state, " grabbedLeft=", grabbedLeft, " enabled_providers=", _debug_enabled_providers())
	_right_controller.trigger_haptic_pulse("haptic",0.0,0.1,0.1,0.0)
	if current_state == null or current_state.get_script() != climbingState:
		print("[CLIMB] RIGHT LETGO: state_after=", current_state, " enabled_providers=", _debug_enabled_providers())
		return
	if(!grabbedLeft):
		set_gravity(true)
		switch_state(initialState.new())
	print("[CLIMB] RIGHT LETGO: state_after=", current_state, " enabled_providers=", _debug_enabled_providers())
