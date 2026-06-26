extends Node3D

class_name ExplosionFXControl

var anim_time = 0.0;
var playing = false

@export var particles:CPUParticles3D
@export var audio_stream_player:AudioStreamPlayer3D
@export var expanding_globe:MeshInstance3D
@export var number_callout: PackedScene
@export var particle_threshold:float = 0.75
@export var sound_threshold:float = 0.1
@export var callout_threshold:float = 0.75

var particles_fired:bool = false
var sound_played:bool = false
var callout_spawned:bool = false
var number:int

func play(number):
	self.number = number
	playing=true
	anim_time=0
	particles_fired = false
	callout_spawned = false
	sound_played = false

func _process(delta: float) -> void:
	if(anim_time>1.5):
		playing = false
	if playing:
		animate(anim_time)
		anim_time+=delta

func animate(time_into_animation):
	if not expanding_globe:
		return
	if(time_into_animation>=sound_threshold and not sound_played):
		sound_played = true
		audio_stream_player.play()
		
	if(time_into_animation>=particle_threshold and not particles_fired):
		particles_fired = true
		particles.emitting = true
		
	if(time_into_animation>=callout_threshold and not callout_spawned):
		callout_spawned = true
		var callout_inst:NumberCallout = number_callout.instantiate()
		callout_inst.set_number(number)
		get_tree().root.add_child(callout_inst)
		callout_inst.global_position = global_position
	# Grab the material (instance if possible so each globe has its own state)
	var mat := expanding_globe.get_active_material(0)
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("progress", time_into_animation*2)
