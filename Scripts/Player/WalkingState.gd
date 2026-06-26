extends PlayerState

var SwimmingState = preload("res://Scripts/Player/SwimmingState.gd")

func enter(stateMachine):
	super(stateMachine)
	stateMachine.enable_walk()
	stateMachine.set_gravity(true)
	stateMachine.set_speed(2.0)
	playerStateMachine.bodyNode.motion_mode = XRToolsPlayerBody.MotionMode.MOTION_MODE_GROUNDED
	playerStateMachine.set_height_override(-1.)

func update(delta):
	if(self.playerStateMachine.is_under_water()):
		playerStateMachine.switch_state(SwimmingState.new())
	pass
	
func exit():
	super()
