@tool
extends Node3D

@export var custom_font : Font
@export var custom_3d_font : Font
@export var zylann_example := false
@export var update_in_physics := false
@export var test_text := true
@export var more_test_cases := true
@export var draw_3d_text := true
@export var draw_array_of_boxes := false
@export var draw_text_with_boxes := false
@export var draw_1m_boxes := false
@export_range(0, 5, 0.001) var debug_thickness := 0.1
@export_range(0, 1, 0.001) var debug_center_brightness := 0.75
@export_range(0, 1) var camera_frustum_scale := 0.9

@export_group("Text groups", "text_groups")
@export var text_groups_show_examples := true
@export var text_groups_show_hints := true
@export var text_groups_show_stats := false
@export var text_groups_show_stats_2d := false
@export var text_groups_position := DebugDraw2DConfig.POSITION_LEFT_TOP
@export var text_groups_offset := Vector2i(8, 8)
@export var text_groups_padding := Vector2i(3, 1)
@export_range(1, 100) var text_groups_default_font_size := 15
@export_range(1, 100) var text_groups_title_font_size := 20
@export_range(1, 100) var text_groups_text_font_size := 17

@export_group("Tests", "tests")
@export var tests_use_threads := false
var test_thread : Thread = null
var test_thread_closing := false

var button_presses := {}
var frame_rendered := false
var physics_tick_processed := false

var timer_1 := 0.0
var timer_cubes := 0.0
var timer_3 := 0.0
var timer_text := 0.0


func _process(delta) -> void:
	$OtherWorld.mesh.material.set_shader_parameter("albedo_texture", $OtherWorld/SubViewport.get_texture())

	physics_tick_processed = false
	if not update_in_physics:
		main_update(delta)
		_update_timers(delta)

	_call_from_thread()


func _physics_process(delta: float) -> void:
	if not physics_tick_processed:
		physics_tick_processed = true
		if update_in_physics:
			main_update(delta)
			_update_timers(delta)

		if not zylann_example and more_test_cases:
			_draw_rays_casts()


func main_update(delta: float) -> void:
	_update_keys_just_press()

	if _is_key_just_pressed(KEY_F1):
		zylann_example = !zylann_example

	if zylann_example:
		var _time = Time.get_ticks_msec() / 1000.0
		DebugDraw2D.set_text("Time", _time)
		DebugDraw2D.set_text("Frames drawn", Engine.get_frames_drawn())
		DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
		DebugDraw2D.set_text("delta", delta)

		$HitTest.visible = false
		$LagTest.visible = false
		$PlaneOrigin.visible = false
		$OtherWorld.visible = false
		%ZDepthTestCube.visible = false
		return

	$HitTest.visible = true
	$LagTest.visible = true
	$PlaneOrigin.visible = true
	$OtherWorld.visible = true
	%ZDepthTestCube.visible = true

	$Panel.visible = Input.is_key_pressed(KEY_ALT)
	DebugDraw2D.custom_canvas = %CustomCanvas if Input.is_key_pressed(KEY_ALT) else null

	if _is_key_just_pressed(KEY_CTRL):
		if not Engine.is_editor_hint():
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED if get_viewport().msaa_3d == Viewport.MSAA_4X else Viewport.MSAA_4X

	if not Engine.is_editor_hint():
		if _is_key_just_pressed(KEY_2):
			DebugDraw2D.debug_enabled = !DebugDraw2D.debug_enabled
		if _is_key_just_pressed(KEY_3):
			DebugDrawManager.debug_enabled = !DebugDrawManager.debug_enabled

	if timer_1 < 0:
		timer_1 = 2
	if timer_3 < 0:
		timer_3 = 2

	_draw_zone_title(%SpheresBox, "Spheres")
	_draw_zone_title(%CapsulesBox, "Capsules")
	_draw_zone_title(%CylindersBox, "Cylinders")
	_draw_zone_title(%BoxesBox, "Boxes")
	_draw_zone_title(%LinesBox, "Lines")
	_draw_paths()
	_draw_paths(Vector3(-2, 0, -1), 0)
	_draw_paths(Vector3(2, 0, -1), 1)
	_draw_zone_title(%MiscBox, "Misc")
	_draw_zone_title_pos($Grids/GridCentered.global_position + Vector3(0, 1.5, 0), "Grids", 96, 36)
	_draw_local_xf_box(%LocalTransformRecursiveOrigin.global_transform, 0.05, 10)

	DebugDraw2D.config.text_default_size = text_groups_default_font_size
	DebugDraw2D.config.text_block_offset = text_groups_offset
	DebugDraw2D.config.text_block_position = text_groups_position
	DebugDraw2D.config.text_padding = text_groups_padding
	DebugDraw2D.config.text_custom_font = custom_font

	if test_text:
		_text_tests()

	var lag_test_pos = to_global($LagTest/RESET.get_animation("RESET").track_get_key_value(0, 0))
	_draw_zone_title_pos(lag_test_pos, "Lag test")
	$LagTest.position = lag_test_pos + Vector3(sin(Time.get_ticks_msec() / 100.0) * 2.5, 0, 0)

	if more_test_cases:
		for ray in $HitTest/RayEmitter.get_children():
			ray.set_physics_process_internal(true)
		_more_tests()
	else:
		for ray in $HitTest/RayEmitter.get_children():
			ray.set_physics_process_internal(false)

	_draw_other_world()

	if draw_array_of_boxes:
		_draw_array_of_boxes()


func _text_tests():
	DebugDraw2D.set_text("FPS", "%.2f" % Engine.get_frames_per_second(), 0, Color.GOLD)

	if text_groups_show_examples:
		if timer_text < 0:
			DebugDraw2D.set_text("Some delayed text", "for 2.5s", -1, Color.BLACK, 2.5)
			timer_text = 5

		DebugDraw2D.begin_text_group("-- First Group --", 2, Color.LIME_GREEN, true, text_groups_title_font_size, text_groups_text_font_size)
		DebugDraw2D.set_text("Simple text")
		DebugDraw2D.set_text("Text", "Value", 0, Color.AQUAMARINE)
		DebugDraw2D.set_text("Text out of order", null, -1, Color.SILVER)
		DebugDraw2D.begin_text_group("-- Second Group --", 1, Color.BEIGE)
		DebugDraw2D.set_text("Rendered frames", Engine.get_frames_drawn())
		DebugDraw2D.end_text_group()

	if text_groups_show_stats or text_groups_show_stats_2d:
		DebugDraw2D.begin_text_group("-- Stats --", 3, Color.WHEAT)

		if text_groups_show_stats:
			DebugDraw2D.set_text("3D render stats", "(unavailable)", 0)

		if text_groups_show_stats and text_groups_show_stats_2d:
			DebugDraw2D.set_text("------", null, 64)

		var render_stats_2d := DebugDraw2D.get_render_stats()
		if render_stats_2d and text_groups_show_stats_2d:
			DebugDraw2D.set_text("Text groups", render_stats_2d.overlay_text_groups, 96)
			DebugDraw2D.set_text("Text lines", render_stats_2d.overlay_text_lines, 97)

		DebugDraw2D.end_text_group()

	if text_groups_show_hints:
		DebugDraw2D.begin_text_group("controls", 1024, Color.WHITE, false)
		if not Engine.is_editor_hint():
			DebugDraw2D.set_text("WASD QE, LMB", "To move", 0)
		if not OS.has_feature("web"):
			DebugDraw2D.set_text("Ctrl: toggle anti-aliasing", "MSAA 4x" if get_viewport().msaa_3d == Viewport.MSAA_4X else "Disabled", 2)
		DebugDraw2D.end_text_group()


func _draw_zone_title(_node: Node3D, _title: String) -> void:
	pass


func _draw_zone_title_pos(_pos: Vector3, _title: String, _font_size: int = 128, _outline: int = 72) -> void:
	pass


const _local_mul := 0.45
const _local_mul_vec := Vector3(_local_mul, _local_mul, _local_mul)
var __local_box_recursive = Transform3D.IDENTITY.rotated_local(Vector3.UP, deg_to_rad(30)).translated(Vector3(-0.25, -0.55, 0.25)).scaled(_local_mul_vec)


func _draw_local_xf_box(xf: Transform3D, thickness: float, max_depth: int, depth: int = 0) -> void:
	if depth >= max_depth:
		return
	_draw_local_xf_box(xf * __local_box_recursive.translated(__local_box_recursive.basis.y), thickness * _local_mul, max_depth, depth + 1)


func _draw_other_world() -> void:
	pass


func _draw_rays_casts() -> void:
	_draw_zone_title_pos(%HitTestSphere.global_position, "Line hits", 96, 36)
	for ray in $HitTest/RayEmitter.get_children():
		if ray is RayCast3D:
			ray.force_raycast_update()


func _more_tests() -> void:
	var pl_node: Node3D = $PlaneOrigin
	var xf: Transform3D = pl_node.global_transform
	var normal: Vector3 = xf.basis.y.normalized()
	var _plane = Plane(normal, xf.origin.dot(normal))
	var vp: Viewport = get_viewport()
	if Engine.is_editor_hint() and Engine.get_singleton(&"EditorInterface").get_editor_viewport_3d(0):
		vp = Engine.get_singleton(&"EditorInterface").get_editor_viewport_3d(0)
	var cam = vp.get_camera_3d()
	if cam:
		var dir = vp.get_camera_3d().project_ray_normal(vp.get_mouse_position())
		_plane.intersects_ray(cam.global_position, dir)


func _draw_paths(offset: Vector3 = Vector3.ZERO, max_points: int = -1) -> void:
	var down_vec = -global_transform.basis.y
	var c_count = $LinePath.get_child_count()
	for c_idx in range(c_count if max_points < 0 else min(c_count, max_points)):
		var c = $LinePath.get_child(c_idx)
		if not c is Node3D:
			break
		var _p = (c as Node3D).global_position + offset
		var _pb = (c as Node3D).global_position + down_vec + offset


func _draw_array_of_boxes() -> void:
	var x_size := 50
	var y_size := 50
	var z_size := 3
	var mul := 1
	var cubes_show_time := 1.25
	if draw_1m_boxes:
		x_size = 100
		y_size = 100
		z_size = 100
		mul = 4
		cubes_show_time = 60

	if timer_cubes < 0:
		var _start_time = Time.get_ticks_usec()
		for x in x_size:
			for y in y_size:
				for z in z_size:
					var _pos := Vector3(x * mul, (-4 - z) * mul, y * mul) + global_position
					pass
		print("Draw Cubes GDScript: %.3fms" % ((Time.get_ticks_usec() - _start_time) / 1000.0))
		timer_cubes = cubes_show_time

	if timer_cubes > cubes_show_time:
		timer_cubes = 0


func _ready() -> void:
	_update_keys_just_press()

	await get_tree().process_frame

	if not is_inside_tree():
		return

	DebugDraw2D.config.text_background_color = Color(0.3, 0.3, 0.3, 0.8)


func _is_key_just_pressed(key):
	if (button_presses[key] == 1):
		button_presses[key] = 2
		return true
	return false


func _update_keys_just_press():
	var set_key = func (k: Key):
		if Input.is_key_pressed(k) and button_presses.has(k):
			if button_presses[k] == 0:
				return 1
			else:
				return button_presses[k]
		else:
			return 0
	button_presses[KEY_LEFT] = set_key.call(KEY_LEFT)
	button_presses[KEY_UP] = set_key.call(KEY_UP)
	button_presses[KEY_CTRL] = set_key.call(KEY_CTRL)
	button_presses[KEY_F1] = set_key.call(KEY_F1)
	button_presses[KEY_1] = set_key.call(KEY_1)
	button_presses[KEY_2] = set_key.call(KEY_2)
	button_presses[KEY_3] = set_key.call(KEY_3)


func _update_timers(delta : float):
	timer_1 -= delta
	timer_cubes -= delta
	timer_3 -= delta
	timer_text -= delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_EXIT_TREE:
		_thread_stop()


func _call_from_thread():
	if tests_use_threads and (not test_thread or not test_thread.is_alive()):
		test_thread_closing = false
		test_thread = Thread.new()
		test_thread.start(_thread_body)
	elif not tests_use_threads and (test_thread and test_thread.is_alive()):
		_thread_stop()


func _thread_stop():
	if test_thread and test_thread.is_alive():
		tests_use_threads = false
		test_thread_closing = true
		test_thread.wait_to_finish()


func _thread_body():
	print("Thread started!")
	while not test_thread_closing:
		var boxes = 10
		for y in boxes:
			var offset := sin(TAU / boxes * y + wrapf(Time.get_ticks_msec() / 100.0, 0, TAU))
			if y == 0:
				DebugDraw2D.set_text("thread. sin", offset)
		OS.delay_msec(16)
	print("Thread finished!")
