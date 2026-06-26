extends State

class_name FishState

func update(delta):
	if stateMachine.has_method("get_behaviors"):
		for behavior:MOBehavior in stateMachine.get_behaviors():
			behavior.compute(stateMachine,delta)
	super(stateMachine)
