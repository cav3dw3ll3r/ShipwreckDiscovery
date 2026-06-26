extends MeshInstance3D

class_name VignetteController

@export var anim_speed = 4.0
var base_val:float = 0.
var temporal_strength=0.
var target_progress=0.
var material:ShaderMaterial
var current_progress:float=0.
var current_time
var is_on:bool = false

const max_closed = 0.6
const open_enough = 1.

func _ready() -> void:
	self.visible = true
	#if OS.get_name() == "Android":
		#visible = false
	set_off()
	material = get_active_material(0)
	material.set_shader_parameter("progress",0.)

func impulse(amount):
	temporal_strength+=amount

func set_base_strength(new_strength:float=0.8):
	animate(lerp(max_closed,open_enough,new_strength))

func set_on():
	is_on = true

func set_off():
	is_on=false

func _process(delta: float) -> void:
	if is_on:
		target_progress=lerp(target_progress,clampf(base_val-temporal_strength,0.,1.),delta*10.*anim_speed)
	else:
		target_progress=0.
	temporal_strength=lerp(temporal_strength,0.,delta*10.)
	current_progress = lerp(current_progress,target_progress,delta*anim_speed)
	material.set_shader_parameter("progress",current_progress)

func animate(progress:float):
	base_val=progress
