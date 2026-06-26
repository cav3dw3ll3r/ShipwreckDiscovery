extends StateMachine
class_name FishStateMachine
# Whether predators can eat this fish
@export var edible = true
@export var animation_key_index:int = 0
@export var animation_player:AnimationPlayer
@export var forward_swim_speed:float 
@export var obstacle_check_distance:float = 1.0
@export var is_sunfish = false
@export var extra_behaviors:Array[MOBehavior] = []

@onready var default_state = preload("res://Scripts/Fish/ForwardSwimState.gd")
@onready var random_turn_state = preload("res://Scripts/Fish/RandomTurnState.gd")
@onready var avoidance_state = preload("res://Scripts/Fish/ObjectAvoidanceState.gd")
@onready var control_state = preload("res://Scripts/Fish/WrangledState.gd")

@onready var game_settings:GameSettings = get_tree().get_first_node_in_group("GameSettings")

const standard_fish_behaviors : Array[MOBehavior] = [
	preload("res://Scripts/Fish/Behaviors/close_avoidance.tres"),
	preload("res://Scripts/Fish/Behaviors/clipping_avoidance.tres")
	]

func _ready() -> void:
	var animation_key_name = animation_player.get_animation_list()[animation_key_index]
	if(animation_player.get_animation(animation_key_name)):
		animation_player.get_animation(animation_key_name).loop_mode=Animation.LOOP_LINEAR
		animation_player.play(animation_key_name)
	switch_state(default_state.new())
	# If no extra behaviors are specified, this fish behaves as a "standard fish"
	if len(extra_behaviors) == 0:
		for behavior:MOBehavior in standard_fish_behaviors:
			extra_behaviors.append(behavior)
	for behavior:MOBehavior in get_behaviors():
		behavior.start(self)

func get_behaviors():
	return extra_behaviors

func on_grabbed(grabs):
	if "fish_wrangler" not in game_settings.active_powers: return
	if len(grabs) >= 2:
		switch_state(control_state.new())

func on_letgo(grabs):
	if len(grabs) < 2:
		switch_state(default_state.new())
