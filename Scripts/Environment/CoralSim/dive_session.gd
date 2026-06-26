extends Node
class_name DiveSession

var active_wreck_id: String = ""

# The initial state of the wreck at dive time
var starting_lionfish: int = 0
var starting_trash: float = 0.0
var starting_corals: Dictionary = {}
var dive_start_time: float = 0.0

const TRASH_REEFCOIN_MIN := 5
const TRASH_REEFCOIN_MAX := 10
const LIONFISH_REEFCOIN_MIN := 10
const LIONFISH_REEFCOIN_MAX := 20

# The temporary session ledger
var culled_lionfish: int = 0
var removed_trash: int = 0
var reefcoin_earned: int = 0
var newly_planted_corals: Array[Dictionary] = []
var destroyed_corals: Array[String] = [] # Array of unique IDs

# The Overseer now passes the starting state dictionary upon creation
func initialize(wreck_id: String, initial_state: Dictionary):
	active_wreck_id = wreck_id
	
	# Scribe the starting parameters
	starting_lionfish = initial_state.get("lionfish_present", 0)
	starting_trash = initial_state.get("trash_coverage", 0.0)
	
	# Perform a deep copy of the corals so the Tallyman doesn't accidentally
	# modify the Master Vessel's references directly during the dive
	starting_corals = initial_state.get("corals", {}).duplicate(true) 
	
	# Anchor the chronological start point (Unix time in seconds is highly reliable for save states)
	dive_start_time = Time.get_unix_time_from_system() 
	
	print("DiveSession: Tallyman active for wreck - ", active_wreck_id)
	
	# Connect to the micro-events happening in the VR world
	_connect_world_events()

func _exit_tree() -> void:
	_disconnect_world_events()

func _connect_world_events() -> void:
	if not SignalBus.trash_picked_up.is_connected(_on_trash_picked_up):
		SignalBus.trash_picked_up.connect(_on_trash_picked_up)
	if not SignalBus.lionfish_culled.is_connected(_on_lionfish_culled):
		SignalBus.lionfish_culled.connect(_on_lionfish_culled)
	if not SignalBus.coral_planted.is_connected(_on_coral_planted):
		SignalBus.coral_planted.connect(_on_coral_planted)
	if not SignalBus.coral_damaged.is_connected(_on_coral_damaged):
		SignalBus.coral_damaged.connect(_on_coral_damaged)

func _disconnect_world_events() -> void:
	if SignalBus.trash_picked_up.is_connected(_on_trash_picked_up):
		SignalBus.trash_picked_up.disconnect(_on_trash_picked_up)
	if SignalBus.lionfish_culled.is_connected(_on_lionfish_culled):
		SignalBus.lionfish_culled.disconnect(_on_lionfish_culled)
	if SignalBus.coral_planted.is_connected(_on_coral_planted):
		SignalBus.coral_planted.disconnect(_on_coral_planted)
	if SignalBus.coral_damaged.is_connected(_on_coral_damaged):
		SignalBus.coral_damaged.disconnect(_on_coral_damaged)

func _on_trash_picked_up():
	removed_trash += 1
	reefcoin_earned += randi_range(TRASH_REEFCOIN_MIN, TRASH_REEFCOIN_MAX)

func _on_lionfish_culled(scale_factor: float):
	culled_lionfish += 1
	var base_payout := randi_range(LIONFISH_REEFCOIN_MIN, LIONFISH_REEFCOIN_MAX)
	reefcoin_earned += maxi(1, roundi(base_payout * scale_factor))

func _on_coral_planted(type: CoralData.CoralType, global_pos: Vector3):
	newly_planted_corals.append({
		"type": type,
		"pos": global_pos
	})

func _on_coral_damaged(unique_id: String):
	if not destroyed_corals.has(unique_id):
		destroyed_corals.append(unique_id)

func extract_and_report():
	# Calculate the exact duration of the dive for the Overseer
	var dive_end_time = Time.get_unix_time_from_system()
	var time_spent_seconds = dive_end_time - dive_start_time
	
	var report = {
		"lionfish_delta": culled_lionfish,
		"trash_delta": removed_trash,
		"reefcoin_delta": reefcoin_earned,
		"planted": newly_planted_corals,
		"destroyed": destroyed_corals,
		"duration_seconds": time_spent_seconds # A vital new metric for the report
	}
	
	print("DiveSession: Extraction complete. Duration: ", time_spent_seconds, "s. Sending report to Overseer.")
	SignalBus.dive_completed.emit(active_wreck_id, report)
