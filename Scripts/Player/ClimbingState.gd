extends PlayerState

var walkState = preload("res://Scripts/Player/WalkingState.gd")

var isLeftGrab:bool = false

func enter(stateMachine:StateMachine):
	super(stateMachine)
	playerStateMachine.set_gravity(false)
	playerStateMachine.enable_climb(isLeftGrab)
	isLeftGrab=playerStateMachine.grabbedLeft
	pass

func exit():
	playerStateMachine.set_gravity(true)
	pass

func update(delta):
	if(isLeftGrab and !playerStateMachine.isLeftGrabbed):
		playerStateMachine.switch_state(determineTransitionState())
	if(!isLeftGrab and !playerStateMachine.isRightGrabbed):
		playerStateMachine.switch_state(determineTransitionState())
	pass

# Check a few conditions and return the state the player should enter
# on releasing the climbable object
func determineTransitionState():
	return walkState.new()
	pass
