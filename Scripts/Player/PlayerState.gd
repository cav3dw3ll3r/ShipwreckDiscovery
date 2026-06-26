extends State

class_name PlayerState

# A state more specific to the player. 
# It contains controls for moving the player,
# As well as enabling or disabling certain types
# of controls.

var playerStateMachine:PlayerStateMachine

func enter(stateMachine:StateMachine):
	var playerStateMachine = stateMachine as PlayerStateMachine
	if(!playerStateMachine):
		pass
	self.playerStateMachine = playerStateMachine
	pass

func exit():
	playerStateMachine.clear_all_controls() 
