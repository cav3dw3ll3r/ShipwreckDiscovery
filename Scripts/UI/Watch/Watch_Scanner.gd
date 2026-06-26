extends Control

var previous:PackedScene = preload("res://Prefabs/UI/WatchSubMenus/top_level_menu.tscn")

@onready var back_button:Button = $ScannerDisp/Back
@onready var scanner_display:TextureRect=$ScannerDisp
@onready var scanner_cam:Camera3D = $ScannerCam/Camera3D
@onready var audio_player:AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var left_controller:XRController3D
@onready var cursor = $ScannerDisp/Cursor
@onready var scan_progress_bar = $TextureProgressBar
@onready var no_tgt = $ScannerDisp/NoTGT
var scanning_sound = preload("res://Audio/power-buzz-sfx-loop-86766.mp3")
var no_scan_sound = preload("res://Audio/wronganswer-37702.mp3")
var scan_success = preload("res://Audio/notification-5-140376.mp3")

var scan_point:WorldScanner
var popup_menu:FrontMenu

const scan_fovs = [
	75.0,
	60.0,
	45.0,
	20.0,
	5.0
]

var zooming_in = false
var zooming_out = false
var just_hit:Scannable
var scan_fov_index = 1
var currently_scanning:Scannable
var scanProgress:float
var hit_tgt:ScanTarget
@onready var main_menu:MainMenuTabs = get_tree().get_first_node_in_group("MainMenu")

func _process(delta: float) -> void:
	scanner_cam.global_position = scan_point.global_position
	var forward = scan_point.global_transform.basis.z.normalized()
	var up = scan_point.global_transform.basis.y.normalized()
	scanner_cam.look_at(scan_point.global_position + forward, up)
	if(left_controller):
		handle_input(delta)


func handle_input(delta):
	if left_controller.is_button_pressed("ax_button") and not zooming_out:
		on_zoom_out()
	if not left_controller.is_button_pressed("ax_button"):
		zooming_out=false
	if left_controller.is_button_pressed("by_button") and not zooming_in:
		on_zoom_in()
	if not left_controller.is_button_pressed("by_button"):
		zooming_in=false
	
	var hit_dict = scan_point.scan()
	var hit = null
	if "Scannable" in hit_dict:
		hit = hit_dict["Scannable"]
	
	if "ScanTarget" in hit_dict:
		hit_tgt = hit_dict["ScanTarget"]
	
	if(hit!=just_hit):
		just_hit = hit
		if(hit==null):
			cursor.play("Unlock")
		else:
			cursor.play("Lock")
	
	if left_controller.is_button_pressed("trigger"):
		on_scan(delta)
	else:
		if audio_player.playing:
			audio_player.stop()
		currently_scanning = null
		scanProgress = 0
		scan_progress_bar.value = 0
		no_tgt.play("default")
	pass

func _ready() -> void:
	popup_menu = get_tree().get_first_node_in_group("PopupMenu")
	scan_point = get_tree().get_first_node_in_group("Scanner")
	left_controller = XRHelpers.get_xr_controller(scan_point)
	var view_texture = ViewportTexture.new()
	var scanner_viewport = get_tree().get_first_node_in_group("Scanner")
	view_texture.viewport_path = NodePath(scanner_viewport.get_path())  # absolute path from scene root
	on_zoom_out()
	cursor.play("Unlock")

func play_sound(sound):
	audio_player.stream = sound
	audio_player.play()

func on_scan(delta):
	var scanned = just_hit
	if(scanned!=null):
		if not audio_player.playing:
			play_sound(scanning_sound)
		on_scan_progress(delta)
	else:
		if audio_player.stream == scanning_sound:
			audio_player.stop()
		if not audio_player.playing:
			play_sound(no_scan_sound)
			no_tgt.play("warning")

func on_scan_progress(delta):
	if(just_hit==null): return
	if(just_hit==currently_scanning and scanProgress>=currently_scanning.required_scan_time):
		return
	if(just_hit!=currently_scanning):
		scanProgress = 0
		currently_scanning=just_hit
		scan_progress_bar.value = 0
		return
	if currently_scanning==null:return
	scanProgress+=delta
	no_tgt.play("default")
	scan_progress_bar.value = scanProgress
	if(scanProgress>1.0):
		play_sound(scan_success)
		popup_menu.last_scanned = currently_scanning
		main_menu.last_scanned = currently_scanning
		var scan_state:ScanTarget.SCAN_STATE = hit_tgt.evaluate_scan_state()
		# Only do if fresh
		if scan_state == ScanTarget.SCAN_STATE.FRESH:
			hit_tgt.set_scanned()
			for scan_target:ScanTarget in get_tree().get_nodes_in_group("ScanTarget"):
				scan_target.update_scan_display()
		# Always do:
		if currently_scanning.scannable_type == currently_scanning.ScanType.SUPPORTER:
			main_menu.open_context_menu(currently_scanning.scan_prefab)
			return
		popup_menu.displayMenu(currently_scanning.scan_prefab)

func on_zoom_out():
	zooming_out = true
	if(scan_fov_index>0):
		scan_fov_index-=1
		scanner_cam.fov=scan_fovs[scan_fov_index]

func on_zoom_in():
	zooming_in = true
	if(scan_fov_index<len(scan_fovs)-1):
		scan_fov_index+=1
		scanner_cam.fov=scan_fovs[scan_fov_index]

func on_back():
	var spawn = previous.instantiate()
	get_parent().add_child(spawn)
	queue_free()
