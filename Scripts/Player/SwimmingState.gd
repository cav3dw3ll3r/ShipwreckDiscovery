extends PlayerState

class_name SwimmingState

var WalkingState = preload("res://Scripts/Player/WalkingState.gd")
var SubmergedState = preload("res://Scripts/Player/SubmergedState.gd")

func enter(playerStateMachine):
	super(playerStateMachine)
	playerStateMachine.enable_swim()
	playerStateMachine.set_gravity(false)
	playerStateMachine.set_speed(1.5)

func update(delta):
	if(playerStateMachine.get_depth_under_water()>1):
		playerStateMachine.switch_state(SubmergedState.new())
	pass
