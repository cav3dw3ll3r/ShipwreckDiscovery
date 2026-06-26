extends PlayerState

class_name StaggerState

const staggerTime = 0.5
var timeSpent = 0
# On entry the player won't have any control over anything
func enter(playerStateMachine):
	super(playerStateMachine)

func update(delta):
	timeSpent+=delta
	playerStateMachine.bodyNode.velocity = playerStateMachine.stagger_vector
	if(timeSpent>staggerTime):
		playerStateMachine.switch_state(playerStateMachine.previous_state)

func exit():
	playerStateMachine.staggered=false
