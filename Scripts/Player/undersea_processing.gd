extends Node3D

## When no node is in group "Waves" (e.g. ocean far LOD), use this for surface tests and splash logic.
@export var fallback_water_surface_y: float = 0.0

@onready var worldEnv:WorldEnvironment = $"../../../Environment/WorldEnvironment"
#@onready var clippingPlane:Node3D = $"../../../Environment/ClippingPlane"
@onready var aboveWaterSettings = preload("res://Resources/Optimized_Surface_Environment.tres")
@onready var underWaterSettings = preload("res://Resources/UnderWaterEnvironment.tres")
@onready var bubbleEmitter = $SplashBubbles
@onready var breathBubbleEmitter = $BreathBubbles
@onready var bigSplash = preload("res://Audio/Water/splash-by-blaukreuz-6261.mp3")
@onready var smallSplash = preload("res://Audio/Water/stone-thrown-in-water-splash-195971.wav")
@onready var underAmbience = preload("res://Audio/Water/ChoppedAmbience.wav")
@onready var oceanAmbience = preload("res://Audio/quiet-neighborhood-ambience-light-wind-no-people-28713.mp3")

var underAmbiencePlayer:AudioStreamPlayer
var waves:Waves
var submerged:bool
var lastPos:Vector3
var currentVelocity:Vector3
var fastEntryVelocity = 70
var timeTillBreath = 2.0

var time_elapsed=0.
var tick_time=1/5.

var timeSinceSplash = 0.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	waves = get_tree().get_first_node_in_group("Waves") as Waves
	setup_ambience()
	_apply_initial_environment()

func _apply_initial_environment() -> void:
	var surface_y := _water_height_at(global_position.x, global_position.z)
	if global_position.y + 0.05 < surface_y:
		submerged = true
		worldEnv.environment = underWaterSettings
	else:
		worldEnv.environment = aboveWaterSettings

func _water_height_at(x: float, z: float) -> float:
	if waves and is_instance_valid(waves):
		return waves.getWaveHeight(x, z)
	return fallback_water_surface_y

func process_waves(delta):
	if not waves or not is_instance_valid(waves):
		waves = get_tree().get_first_node_in_group("Waves") as Waves

	currentVelocity = (global_position-lastPos)/delta
	lastPos = global_position
	if submerged:
		underWaterSettings.ambient_light_energy=clamp(1.2-abs(global_position.y/100)*1.,0.,1.3)
	var surface_y := _water_height_at(global_position.x, global_position.z)
	if global_position.y + 0.05 < surface_y and not submerged:
		submerge()
	elif global_position.y + 0.05 > surface_y and submerged:
		surface()

func _process(delta: float) -> void:
	time_elapsed+=delta
	if time_elapsed>tick_time:
		process_waves(tick_time)
		time_elapsed-=tick_time

func splash():
	if waves and is_instance_valid(waves):
		waves.create_splash(global_position.x, global_position.z, abs(currentVelocity.y) / 8.0)

func surface():
	submerged = false
	worldEnv.environment = aboveWaterSettings
	#clippingPlane.visible = true
	underAmbiencePlayer.stream = oceanAmbience
	underAmbiencePlayer.play()
	for sound:AudioStreamPlayer3D in get_tree().get_nodes_in_group("Above Water Sounds"):
		sound.play()

func submerge():
	submerged=true
	worldEnv.environment = underWaterSettings
	#clippingPlane.visible = false
	# Emit bubbles on entry
	bubbleEmitter.amount_ratio = abs(currentVelocity.y)/fastEntryVelocity
	bubbleEmitter.emitting=true
	underAmbiencePlayer.stream = underAmbience
	underAmbiencePlayer.play()
	if(currentVelocity.y<-fastEntryVelocity/5.):
		play_sound(bigSplash)
	elif(currentVelocity.y<-fastEntryVelocity/13.):
		play_sound(smallSplash)
	splash()
	for sound:AudioStreamPlayer3D in get_tree().get_nodes_in_group("Above Water Sounds"):
		sound.stop()
	pass

func play_sound(sound:AudioStream):
	var player = AudioStreamPlayer.new()
	player.stream = sound
	player.bus = "SFX"
	add_child(player)
	player.play()
	player.connect("finished",player.queue_free)

func setup_ambience():
	underAmbiencePlayer = AudioStreamPlayer.new()
	underAmbiencePlayer.stream = oceanAmbience
	underAmbiencePlayer.bus = "Ambience"
	add_child(underAmbiencePlayer)
	underAmbiencePlayer.play()
