extends PlayerState

class_name RespawnState

const respawnTime = 2.0
var timeSpent = 0
var vignetteTarget = 1.0

# On entry the player won't have any control over anything
func enter(playerStateMachine):
	super(playerStateMachine)
	playerStateMachine.remainingHealth=100
	playerStateMachine.remainingAir=100
	playerStateMachine.vignette_on(false)
	playerStateMachine.eyelids_close()

func update(delta):
	timeSpent+=delta
	if(timeSpent<respawnTime):
		vignetteTarget+=delta
	else:
		playerStateMachine.switch_state(playerStateMachine.initialState.new())
	

func exit():
	playerStateMachine.reset_position()
	playerStateMachine.staggered=false
	playerStateMachine.remainingAir = 100
	playerStateMachine.remainingHealth=100
	playerStateMachine.air_event.emit()
	playerStateMachine.damage_event.emit()
	playerStateMachine.vignette_on(true)
	playerStateMachine.eyelids_open()
