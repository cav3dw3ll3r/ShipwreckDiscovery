extends PlayerState

class_name SubmergedState

var WalkingState = preload("res://Scripts/Player/WalkingState.gd")
var SwimState = preload("res://Scripts/Player/SwimmingState.gd")

var time_since_air_deduction=0
const air_deduct_frequency = 12
const sprint_air_drain_multiplier = 3.0

const SAFE_VERTICAL_VELOCITY = 1 # meters/sec, adjust as needed
const RISK_ACCUMULATOR_MAX = 100.0
const RISK_ACCUMULATOR_MIN = 0.0
const RISK_ACCUMULATOR_RATE = 20.0 # risk per second per m/s over threshold
const RISK_RECOVERY_RATE = 10.0 # risk recovery per second

var _rapid_tap_sprint: RapidTapSprint

func enter(playerStateMachine):
	super(playerStateMachine)
	playerStateMachine.enable_submerged()
	playerStateMachine.set_gravity(false)
	playerStateMachine.barotrauma_risk_accumulator = 0.0
	playerStateMachine.set_speed(1.2)
	playerStateMachine.set_height_override(0.5)
	var session_manager = playerStateMachine.get_tree().root.get_node_or_null("SessionManager")
	if session_manager != null and session_manager.has_method("begin_current_level_dive"):
		session_manager.begin_current_level_dive()
	_rapid_tap_sprint = playerStateMachine.get_node_or_null(
		"../XRController3D_right/RapidTapSprint") as RapidTapSprint

func update(delta):
	var air_drain_rate := 1.0
	if _rapid_tap_sprint and _rapid_tap_sprint.enabled:
		air_drain_rate += sprint_air_drain_multiplier * _rapid_tap_sprint.get_burst_intensity()

	time_since_air_deduction += delta * air_drain_rate
	if(playerStateMachine.bodyNode.on_ground):
		#playerStateMachine.bodyNode.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
		playerStateMachine.bodyNode.request_jump(false)
	if(time_since_air_deduction>=air_deduct_frequency or (playerStateMachine.remainingAir<=0 and time_since_air_deduction>=1)):
		time_since_air_deduction=0
		if "aqua_lung" not in playerStateMachine.game_settings.active_powers:
			playerStateMachine.lose_air(1)
	
	#calculate_barotrauma_risk()
	
	if(playerStateMachine.get_depth_under_water()<1):
		playerStateMachine.switch_state(SwimState.new())
	pass

func exit():
	super()
	playerStateMachine.barotrauma_risk_accumulator = 0.0
	_rapid_tap_sprint = null

func calculate_barotrauma_risk():
	var up_down_rate = playerStateMachine.rolling_avg_vertical_velocity
	if up_down_rate > SAFE_VERTICAL_VELOCITY:
		playerStateMachine.barotrauma_risk_accumulator += (up_down_rate - SAFE_VERTICAL_VELOCITY) * RISK_ACCUMULATOR_RATE * playerStateMachine.get_process_delta_time()
	else:
		playerStateMachine.barotrauma_risk_accumulator -= RISK_RECOVERY_RATE * playerStateMachine.get_process_delta_time()
	playerStateMachine.barotrauma_risk_accumulator = clamp(playerStateMachine.barotrauma_risk_accumulator, RISK_ACCUMULATOR_MIN, RISK_ACCUMULATOR_MAX)
	# Optionally apply damage if risk is maxed
	if playerStateMachine.barotrauma_risk_accumulator >= RISK_ACCUMULATOR_MAX:
		playerStateMachine.barotrauma_risk_accumulator = 0
		if "swim_bladder" not in playerStateMachine.game_settings.active_powers:
			playerStateMachine.take_damage(60,10,playerStateMachine)
