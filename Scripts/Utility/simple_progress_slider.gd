extends MeshInstance3D

class_name Progress_Animator

@export var anim_speed = 4.0
@export var on_val:float = 1.0
@export var off_val:float = 0.
var material:ShaderMaterial
var current_progress:float
var current_time
var _animate_epoch: int = 0
var _reopen_timer: SceneTreeTimer

signal done

func _ready() -> void:
	self.visible = true
	material = get_active_material(0)

func set_on():
	animate(on_val)

func set_off():
	animate(off_val)

func schedule_set_on_after(seconds: float) -> void:
	if _reopen_timer:
		if _reopen_timer.timeout.is_connected(_on_reopen_timeout):
			_reopen_timer.timeout.disconnect(_on_reopen_timeout)
		_reopen_timer = null
	_reopen_timer = get_tree().create_timer(seconds)
	_reopen_timer.timeout.connect(_on_reopen_timeout, CONNECT_ONE_SHOT)

func _on_reopen_timeout() -> void:
	set_on()

func animate(progress:float):
	_animate_epoch += 1
	var epoch := _animate_epoch
	current_progress = material.get_shader_parameter("progress")
	current_time = Time.get_ticks_usec()
	while(abs(current_progress-progress)>0.001):
		if epoch != _animate_epoch:
			return
		var delta = (Time.get_ticks_usec()-current_time)/1000000.
		current_progress = lerp(current_progress,progress,delta*anim_speed)
		material.set_shader_parameter("progress",current_progress)
		current_time=Time.get_ticks_usec()
		await get_tree().process_frame
	if epoch != _animate_epoch:
		return
	emit_signal("done")
