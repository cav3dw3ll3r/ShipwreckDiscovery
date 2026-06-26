extends State

class_name ObjectAvoidanceState

#Simple 180 degree snap-turn to refine later. 
func enter(stateMachine):
	super(stateMachine)

func update(delta):
	stateMachine.rotation_degrees.y += 180.0
	stateMachine.switch_state(stateMachine.default_state.new())
