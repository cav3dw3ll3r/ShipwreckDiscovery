class_name DiveManager

@export var wreck_name: String = "Atlantis"

# Persistent metrics stored via SaveLoad system
var health: float = 0.35
var total_lionfish_count: int = 42
var total_coral_planted: int = 5
var apex_discovered: bool = false


# Temporary tracking for the active dive run
var session_metrics: Dictionary = {
	"trash_collected": 0,
	"lionfish_killed": 0,
	"coral_planted": 0,
	"start_time":0.,
	"end_time":0.
}

var data = {
	"Atlantis":{
	"health":0.35,
	"lionfish_present":50,
	"trash_coverage":0.9,
	"coral_coverage":0.1},
	}

# Class members for normal usage
var dive_start_time: float = 0.0
var dive_end_time: float = 0.0

func get_wreck_health(wreck_id:String):
	return 

func _ready() -> void:
	# Listen to your game world events
	SignalBus.trash_picked_up.connect(_on_trash_collected)
	SignalBus.lionfish_culled.connect(_on_lionfish_killed)
	SignalBus.coral_planted.connect(_on_coral_planted)
	SignalBus.dive_started.connect(_on_dive_started)
	SignalBus.dive_ended.connect(_on_dive_ended)

func get_dive_time() -> float:
	# If the dive is still active, calculate time passed from start until now
	if dive_end_time == 0.0:
		return (Time.get_ticks_msec() - dive_start_time) / 1000.0 # Returns total seconds
	# If dive ended, return the locked total duration
	return (dive_end_time - dive_start_time) / 1000.0

func _on_dive_started() -> void:
	# Clean reset of the session tracking run
	session_metrics = {
		"trash_collected": 0,
		"lionfish_killed": 0,
		"coral_planted": 0,
		"duration_seconds": 0.0
	}
	dive_end_time = 0.0
	dive_start_time = Time.get_ticks_msec()

func _on_dive_ended() -> void:
	dive_end_time = Time.get_ticks_msec()
	session_metrics["duration_seconds"] = get_dive_time()

func _on_trash_collected() -> void:
	session_metrics.trash_collected += 1

func _on_lionfish_killed(_scale_factor: float = 1.0) -> void:
	session_metrics.lionfish_killed += 1

func _on_coral_planted() -> void:
	session_metrics.coral_planted += 1

# Call this to wrap up the level state before swapping back to the boat cabin scene
func complete_dive() -> void:
	# Calculate systemic health adjustments
	total_lionfish_count = max(0, total_lionfish_count - session_metrics.lionfish_killed)
	total_coral_planted += session_metrics.coral_planted
	
	var health_gain = (session_metrics.trash_collected * 0.02) + (session_metrics.coral_planted * 0.05)
	var health_loss = (total_lionfish_count * 0.001)
	health = clamp(health + health_gain - health_loss, 0.0, 1.0)
	
	if health >= 0.90:
		apex_discovered = true
	
	# Cache session statistics inside your Global UI layer or Autoload for the post-dive screen
	#GlobalMenuCache.last_dive_summary = session_metrics
	#GlobalMenuCache.last_dive_wreck_name = wreck_name
	
	# Trigger your existing pipeline to save all registered nodes
	SaveLoad.save_game() 
	
	#get_tree().change_scene_to_file("res://scenes/boat_cabin.tscn")

# --- SAVEABLE IMPLEMENTATION ---

func get_state() -> Dictionary:
	return {
		"health": health,
		"total_lionfish_count": total_lionfish_count,
		"total_coral_planted": total_coral_planted,
		"apex_discovered": apex_discovered
	}

func restore_state(data: Dictionary) -> void:
	health = data.get("health", 0.35)
	total_lionfish_count = data.get("total_lionfish_count", 42)
	total_coral_planted = data.get("total_coral_planted", 5)
	apex_discovered = data.get("apex_discovered", false)
