# Used as the base for anything that runs on a state machine
# This will be used to hold all the state driven behavior.  
extends Node3D

class_name StateMachine

var current_state:State
var has_control:bool = true

func set_has_control(has_control):
	self.has_control=has_control

func switch_state(new_state: State):
	if(current_state):
		current_state.exit()
	current_state = new_state
	current_state.enter(self)

func _process(delta):
	if(current_state and has_control):
		current_state.update(delta)
