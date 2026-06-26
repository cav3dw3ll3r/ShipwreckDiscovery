extends FishState



var total_turn_amount
var amount_turned = 0
var turn_speed = 5.0

func enter(stateMachine):
	super(stateMachine)
	turn_speed = randf_range(5.0,25.0)
	total_turn_amount = randf_range(-180.0,180.0)

func update(delta):
	super(delta)
	stateMachine.position+=-stateMachine.transform.basis.z * delta * stateMachine.forward_swim_speed
	var turn_amount = delta * turn_speed
	if(total_turn_amount<0):
		turn_amount*=-1.0
	stateMachine.rotation_degrees.y += turn_amount
	amount_turned += turn_amount
	if abs(amount_turned)>=abs(total_turn_amount):
		stateMachine.switch_state(stateMachine.default_state.new())
