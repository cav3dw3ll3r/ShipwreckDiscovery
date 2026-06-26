extends FishState

var turn_frequency = 5.0
var forward_speed = 0.0

func enter(stateMachine):
	super(stateMachine)
	forward_speed = stateMachine.forward_swim_speed+randf_range(-0.5,1.5)

func update(delta):
	super(delta)
	stateMachine.position+=-stateMachine.transform.basis.z * delta * forward_speed
	
	turn_frequency-=delta
	if(turn_frequency<=0):
		stateMachine.switch_state(stateMachine.random_turn_state.new())
