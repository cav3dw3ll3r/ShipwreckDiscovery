extends MarginContainer

class_name DynamicScanPanel

@export var thisScanDataPath: String
@export var fileName: String

@onready var listingContainer = $ScrollContainer/VBoxContainer

@onready var reward_display:RewardTracking = $MainLayout/RewardSection

var scan: Dictionary = {}
var video_dir: String
var video_clips = []
var icon_dir:String

var bound_scannable:Scannable

func _ready():
	pass

func on_close():
	if $MainLayout.get_child(0).has_method("on_close"):
		$MainLayout.get_child(0).on_close()

func update_panel():
	get_videos_from_scan()
	reward_display.setup_reward_display(bound_scannable, 0)
	await get_tree().process_frame
	if(len(video_clips)>0):
		update_panel_video()
	else:
		update_panel_no_video()

#TODO: Get rid of the normal scan content and drop a video player in.
#		Then set up the video with clips from the database.
func update_panel_video():
	# Remove or hide normal scan content if needed
	$MainLayout/Details.queue_free()
	$MainLayout/Name.queue_free()
	$MainLayout/SubHeading.queue_free()

	# Instance the video player scene
	var video_player_scene = load("res://Prefabs/UI/ScanPanels/video_player.tscn") # <-- update path!
	var video_player:VideoPlayer = video_player_scene.instantiate()

	# Convert video_clips (paths) to VideoStream resources
	var streams:Array[VideoStream] = []
	var filenames:Array[String] = []
	for clip_path in video_clips:
		await get_tree().process_frame
		var stream = load(bound_scannable.videoDir+clip_path)
		var full_path = bound_scannable.videoDir + clip_path
		if stream is VideoStream:
			streams.append(stream)
			filenames.append(clip_path)
		else:
			push_error("Failed to load video stream: " + clip_path)

	video_player.clips = streams
	video_player.clip_file_names = filenames

	# Optionally, set up the player node if needed (if not set via @export)
	# video_player.player = video_player.get_node("VideoStreamPlayer")

	# Add to your UI (choose the right container)
	$MainLayout.add_child(video_player)
	$MainLayout.move_child(video_player,0)

func update_panel_no_video():
	var name_control = $MainLayout/Name
	var sub_header = $MainLayout/SubHeading
	var icon_rect = $MainLayout/Details/TextureRect
	
	var desc_control = $MainLayout/Details/Description1
	icon_rect.texture = load(icon_dir+"//"+scan["Icon"])
	name_control.text = scan["Name"]
	desc_control.text = scan["Description"]
	sub_header.text = scan["Category"]

func get_videos_from_scan():
	# clear for safety
	video_clips.clear()
	if "Video1" not in scan: return
	# populate
	if scan["Video1"] != "":
		video_clips.append(scan["Video1"])
	if scan["Video2"] != "":
		video_clips.append(scan["Video2"])
	if scan["Video3"] != "":
		video_clips.append(scan["Video3"])
	if scan["Video4"] != "":
		video_clips.append(scan["Video4"])
	if scan["Video5"] != "":
		video_clips.append(scan["Video5"])
	if scan["Video6"] != "":
		video_clips.append(scan["Video6"])

func read_from_file(scannable:Scannable):
	bound_scannable = scannable
	var dataPath = scannable.dataPath
	var targetDataID = scannable.scannable_ID
	icon_dir = scannable.iconDir
	# Open the CSV file for reading
	var file = FileAccess.open(dataPath, FileAccess.READ)
	if file:
		var header = file.get_line()
		var keys = header.split("\t")  # Split the header into keys
		while not file.eof_reached():
			var line = file.get_line()
			if line == "":  # Skip empty lines
				continue
			var values = line.split("\t")  # Split the line into values
			if(values[0] != targetDataID): continue
			var row_data = {}
			for i in range(len(keys)):
				row_data[keys[i]] = values[i]  # Map keys to values
			scan=row_data
			file.close()
			return
	else:
		push_error("Failed to open file: " + thisScanDataPath)

func add_dynamic_scan_content(scannable:Scannable):
	read_from_file(scannable)
	await get_tree().process_frame
	update_panel()
	pass
