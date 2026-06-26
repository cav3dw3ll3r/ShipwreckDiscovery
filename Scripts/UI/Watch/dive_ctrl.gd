extends Control

var previous:PackedScene = preload("res://Prefabs/UI/WatchSubMenus/top_level_menu.tscn")

@onready var ascent_meter:TextureProgressBar = $AscentRate
@onready var descent_meter:TextureProgressBar = $DescentRate
@onready var player_state_machine:PlayerStateMachine = get_tree().get_first_node_in_group("Player").get_node("../PlayerStateMachine")

var world_scale_multiplier = 0.74

var max_ascent = 0.15
var max_descent = 0.5

var isImperial = false
var isGoingUp = true

var time_since_tick = 0
@onready var temp_rand = get_tree().get_first_node_in_group("GameSettings").temp_variation

func _ready():
	on_unit_swap()

func _process(delta: float) -> void:
	time_since_tick += delta
	if time_since_tick >= 0.05:
		time_since_tick = 0
		refresh_display()

func refresh_display():
	var up_down_rate = -player_state_machine.rolling_avg_vertical_velocity
	if up_down_rate < -0.5:
		isGoingUp = true
	if up_down_rate > 0.5:
		isGoingUp = false
	var barotrauma_risk = player_state_machine.barotrauma_risk_accumulator
	if not isGoingUp:
		descent_meter.value = 0
		ascent_meter.value = barotrauma_risk
	else:
		ascent_meter.value = 0
		descent_meter.value = abs(barotrauma_risk)
	
	var depth_meters = player_state_machine.get_depth_under_water()*world_scale_multiplier
	var temp_c = get_temperature(depth_meters*world_scale_multiplier)
	if isImperial:
		$DepthValue.text = "%.2f" % to_feet(depth_meters)
		$TempValue.text = "%.2f" % to_fahrenheit(temp_c)
	else:
		$DepthValue.text = "%.2f" % depth_meters
		$TempValue.text = "%.2f" % temp_c


func get_temperature(depth_m: float) -> float:
	# Example values (adjust based on season or data)
	var surface_temp = 26.0  # in °C (summer average)
	var bottom_temp = 18.0   # in °C (at deeper layers)
	var thermocline_top = 3.0   # depth in meters
	var thermocline_bottom = 45.0  # depth in meters

	if depth_m <= thermocline_top:
		return surface_temp+temp_rand
	elif depth_m <= thermocline_bottom:
		# Linear interpolation within thermocline
		var fraction = (depth_m - thermocline_top) / (thermocline_bottom - thermocline_top)
		return lerp(surface_temp, bottom_temp, fraction)+temp_rand
	else:
		return bottom_temp+temp_rand

func to_feet(meters):
	return meters*3.208

func to_fahrenheit(celsius):
	return (celsius*1.8)+32

func on_unit_swap():
	isImperial = not isImperial
	if(isImperial):
		$ImperialMetricButton.stringID = "imperial"
		$TempUnits.text = "°F"
		$DepthUnits.text = "ft"
	else:
		$ImperialMetricButton.stringID = "metric"
		$TempUnits.text = "°C"
		$DepthUnits.text = "m"
	$ImperialMetricButton.refresh()

func on_back():
	var spawn = previous.instantiate()
	get_parent().add_child(spawn)
	queue_free()
