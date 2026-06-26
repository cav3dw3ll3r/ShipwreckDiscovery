extends Node
# Autoload Name: SessionManager

# --- SaveLoad Interface Properties ---
var uuid: String = "campaign_master" 

# The Master Ledger
var master_vessel: Dictionary = {}
var blueprints_verified: bool = false
var available_blueprints: Array[LevelData] = []
var last_completed_dive_date = null
var reefcoin: int = 0

const LEVEL_DIRECTORY = "res://Resources/Levels/"
const SAVE_KEY_MASTER_VESSEL := "master_vessel"
const SAVE_KEY_LAST_COMPLETED_DIVE_DATE := "last_completed_dive_date"
const SAVE_KEY_REEFCOIN := "reefcoin"
const TRASH_COVERAGE_PER_PICKUP := 1.0 / 50.0

# The active Tallyman
var current_dive: DiveSession = null

signal wreck_visuals_changed(wreck_id: String)

func _ready():
	_gather_blueprints()
	
	# Register this manager with the SaveLoad immediately upon boot
	SaveLoad.register_saveable(self)
	
	# Bind the Overseer to the macroscopic signals
	SignalBus.dive_started.connect(_on_dive_started)
	SignalBus.dive_completed.connect(_on_dive_completed)

func _gather_blueprints():
	var dir = DirAccess.open(LEVEL_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var loaded_blueprint = load(LEVEL_DIRECTORY + file_name) as LevelData
				if loaded_blueprint:
					available_blueprints.append(loaded_blueprint)
			file_name = dir.get_next()
		print("Session Manager: Automatically loaded ", available_blueprints.size(), " blueprints from ", LEVEL_DIRECTORY)
	else:
		push_error("Session Manager: Could not access level directory at ", LEVEL_DIRECTORY)

# ==========================================
# SAVE SYSTEM INTERFACE METHODS
# ==========================================

func get_state() -> Dictionary:
	return {
		SAVE_KEY_MASTER_VESSEL: master_vessel,
		SAVE_KEY_LAST_COMPLETED_DIVE_DATE: last_completed_dive_date,
		SAVE_KEY_REEFCOIN: reefcoin,
	}

func restore_state(saved_data: Dictionary):
	if saved_data.has(SAVE_KEY_MASTER_VESSEL):
		master_vessel = saved_data.get(SAVE_KEY_MASTER_VESSEL, {})
		last_completed_dive_date = saved_data.get(SAVE_KEY_LAST_COMPLETED_DIVE_DATE, null)
		reefcoin = saved_data.get(SAVE_KEY_REEFCOIN, 0)
	else:
		# Older saves stored the wreck ledger directly under this saveable.
		master_vessel = saved_data
		last_completed_dive_date = null
		reefcoin = 0
	print("Session Manager: Data restored from SaveLoad.")
	_verify_blueprints()

# ==========================================
# CAMPAIGN LOGIC
# ==========================================

# Call this manually if booting the game for the very first time 
# (when no save file exists to trigger restore_state automatically)
func initialize_new_campaign():
	if not blueprints_verified:
		_verify_blueprints()

func _verify_blueprints():
	if available_blueprints.is_empty():
		return

	for blueprint in available_blueprints:
		var wreck_id = blueprint.nameID
		
		# If the restored save data doesn't have this wreck, generate it
		if not master_vessel.has(wreck_id):
			print("Session Manager: Generating baseline for ", wreck_id)
			_generate_baseline_for_wreck(blueprint)
			
	blueprints_verified = true

func register_level_blueprints(level_blueprints: Array) -> void:
	var added_count := 0
	for blueprint in level_blueprints:
		if not blueprint is LevelData:
			continue
		var already_available := false
		for existing in available_blueprints:
			if existing.nameID == blueprint.nameID:
				already_available = true
				break
		if not already_available:
			available_blueprints.append(blueprint)
			added_count += 1

	if added_count > 0:
		blueprints_verified = false
	if not blueprints_verified:
		_verify_blueprints()

func _generate_baseline_for_wreck(blueprint: LevelData):
	var baseline_state = {
		"lionfish_present": blueprint.initial_lionfish,
		"trash_coverage": blueprint.initial_pollution,
		"fish_biomass": blueprint.initial_fish_biomass,
		"corals": {}
	}
	
	if blueprint.initial_corals:
		for coral in blueprint.initial_corals:
			# Generate the spatial fingerprint ID
			var c_pos = coral.global_position
			var coral_id = "c_%d_%d_%d" % [round(c_pos.x), round(c_pos.y), round(c_pos.z)]
			baseline_state["corals"][coral_id] = coral.to_dict()
			
	master_vessel[blueprint.nameID] = baseline_state

# ==========================================
# DIVE MANAGER HANDOVER
# ==========================================

func get_wreck_state(wreck_id: String) -> Dictionary:
	return master_vessel.get(wreck_id, {})


func has_completed_dive() -> bool:
	return last_completed_dive_date != null


func get_reefcoin() -> int:
	return reefcoin


func get_current_dive_elapsed_seconds() -> int:
	if current_dive == null:
		return 0

	return maxi(0, int(Time.get_unix_time_from_system() - current_dive.dive_start_time))


func get_days_since_last_completed_dive() -> int:
	if last_completed_dive_date == null:
		return 0

	var today_day := _date_to_unix_day(_get_current_date())
	var last_dive_day := _date_to_unix_day(last_completed_dive_date)
	if last_dive_day < 0:
		return 0
	return maxi(1, today_day - last_dive_day)


func is_dive_active() -> bool:
	return current_dive != null


func begin_current_level_dive() -> bool:
	if is_dive_active():
		return false

	var wreck_id := _resolve_current_wreck_id()
	if wreck_id.is_empty():
		push_warning("Session Manager: Cannot begin dive without a current wreck id.")
		return false

	SignalBus.dive_started.emit(wreck_id)
	return true


func end_current_dive() -> bool:
	if current_dive == null:
		return false

	current_dive.extract_and_report()
	return true


## Authoritative coral ledger for world placement. Merges in-dive deltas when a dive is active.
func get_corals_for_wreck(wreck_id: String) -> Dictionary:
	var state := get_wreck_state(wreck_id)
	var corals: Dictionary = state.get("corals", {}).duplicate(true)

	if current_dive != null and current_dive.active_wreck_id == wreck_id:
		for dead_id in current_dive.destroyed_corals:
			corals.erase(dead_id)
		for new_coral in current_dive.newly_planted_corals:
			var c_pos: Vector3 = new_coral["pos"]
			var new_id := "c_%d_%d_%d" % [round(c_pos.x), round(c_pos.y), round(c_pos.z)]
			var default_stage := {
				"pos": var_to_str(Vector3.ZERO),
				"rot": 0.0,
				"scale": 1.0,
			}
			corals[new_id] = {
				"pos": var_to_str(c_pos),
				"biomass": 0.1,
				"resilience": 1.0,
				"type": new_coral["type"],
				"baby": default_stage,
				"growing": default_stage,
				"pristine": default_stage,
			}

	return corals


func get_blueprint_by_id(wreck_id: String) -> LevelData:
	for blueprint in available_blueprints:
		if blueprint.nameID == wreck_id:
			return blueprint
	return null


func get_wreck_display_data(wreck_id: String, blueprint: LevelData) -> Dictionary:
	var state := get_wreck_state(wreck_id)
	var display := WreckStatusEvaluator.evaluate(state, blueprint)
	return display


func get_wreck_reef_health(wreck_id: String, blueprint: LevelData = null) -> float:
	var resolved_blueprint := blueprint if blueprint != null else get_blueprint_by_id(wreck_id)
	return WreckStatusEvaluator.calculate_reef_health(get_wreck_state(wreck_id), resolved_blueprint)


func get_wreck_fish_biomass_ratio(wreck_id: String, blueprint: LevelData = null) -> float:
	var resolved_blueprint := blueprint if blueprint != null else get_blueprint_by_id(wreck_id)
	if resolved_blueprint == null or resolved_blueprint.target_biomass <= 0.0:
		return 0.0
	var state := get_wreck_state(wreck_id)
	var fish_biomass: float = state.get("fish_biomass", 0.0)
	return clampf(fish_biomass / resolved_blueprint.target_biomass, 0.0, 1.0)


func _resolve_current_wreck_id() -> String:
	var game_settings := get_tree().get_first_node_in_group("GameSettings") as GameSettings
	if game_settings == null or game_settings.current_level.is_empty():
		return ""

	var level_data := load(game_settings.current_level) as LevelData
	return level_data.nameID if level_data else ""


func _get_current_date() -> Dictionary:
	var date := Time.get_date_dict_from_system()
	return {
		"year": date["year"],
		"month": date["month"],
		"day": date["day"],
	}


func _date_to_unix_day(date) -> int:
	if not date is Dictionary:
		return -1

	var datetime := {
		"year": date.get("year", 1970),
		"month": date.get("month", 1),
		"day": date.get("day", 1),
		"hour": 0,
		"minute": 0,
		"second": 0,
	}
	return int(Time.get_unix_time_from_datetime_dict(datetime) / 86400.0)


func _on_dive_started(wreck_id: String):
	if current_dive != null:
		push_error("Session Manager: A dive is already in progress!")
		return
		
	if not master_vessel.has(wreck_id):
		push_warning("Session Manager: Wreck state not found. Generating fallback baseline.")
		# A safeguard in case a new blueprint was added mid-campaign without a verification trigger
		for bp in available_blueprints:
			if bp.nameID == wreck_id:
				_generate_baseline_for_wreck(bp)
				break
	
	# Grab the exact starting state from the Master Vessel
	var starting_state = master_vessel.get(wreck_id, {})
	
	# Conjure the Tallyman
	current_dive = DiveSession.new()
	add_child(current_dive) 
	
	# Pass both the ID and the starting state dictionary
	current_dive.initialize(wreck_id, starting_state) 

func _on_dive_completed(wreck_id: String, dive_report: Dictionary):
	# 1. Apply the ledger to our persistent master vessel
	_apply_dive_report(wreck_id, dive_report)
	last_completed_dive_date = _get_current_date()
	
	# 2. Command the SaveLoad to commit to disk immediately
	SaveLoad.save_all()
	
	# 3. Banish the Tallyman. The session is over.
	if current_dive:
		current_dive.queue_free()
		current_dive = null

# The Alchemical Transmutation: Merging temporary gameplay with permanent storage
func _apply_dive_report(wreck_id: String, report: Dictionary):
	var state = master_vessel[wreck_id]
	
	# Apply subtractions (Ensure we don't go below 0)
	state["lionfish_present"] = max(0, state["lionfish_present"] - report["lionfish_delta"])
	state["trash_coverage"] = max(0.0, state["trash_coverage"] - (report["trash_delta"] * TRASH_COVERAGE_PER_PICKUP))
	var reefcoin_delta: int = report.get("reefcoin_delta", 0)
	reefcoin += reefcoin_delta
	if reefcoin_delta > 0:
		SignalBus.on_coin_earned.emit(reefcoin_delta, reefcoin)
	
	# Apply destructions
	for dead_id in report["destroyed"]:
		if state["corals"].has(dead_id):
			state["corals"].erase(dead_id)
			
	# Apply new plantings
	for new_coral in report["planted"]:
		var c_pos = new_coral["pos"]
		var new_id = "c_%d_%d_%d" % [round(c_pos.x), round(c_pos.y), round(c_pos.z)]
		
		var default_stage := {
			"pos": var_to_str(Vector3.ZERO),
			"rot": 0.0,
			"scale": 1.0,
		}
		state["corals"][new_id] = {
			"pos": var_to_str(c_pos),
			"biomass": 0.1, # Starting baby biomass
			"resilience": 1.0,
			"type": new_coral["type"],
			"baby": default_stage,
			"growing": default_stage,
			"pristine": default_stage,
		}
		
	print("Session Manager: Master Vessel updated for ", wreck_id, " | Dive Duration: ", report["duration_seconds"], "s")
	wreck_visuals_changed.emit(wreck_id)
