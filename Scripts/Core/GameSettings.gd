@tool
extends Saveable
# Contains player settings plus runtime values derived from campaign state.
class_name GameSettings

enum Language {
	ENGLISH,
	SPANISH,
	FRENCH,
	GERMAN,
	RUSSIAN
}

@export var is_free_play:bool
const MURKY_REEF_FOG_DEPTH_CURVE: float = 0.02
const CLEAR_REEF_FOG_DEPTH_CURVE: float = 0.31864157

var visibility:float = MURKY_REEF_FOG_DEPTH_CURVE
var reef_health: float = 0.0
@export var ocean_currents:Vector2 = Vector2.ZERO
@export var wave_intensity:float=0.01
@export var sfx_volume:float
@export var voice_volume:float
@export var ambience_volume:float
@export var language:Language
@export var max_fish:int = 10
@export var mute_videos:bool = false
@export var switch_hands:bool = false
@export var amateur_mode:bool = false

var current_fish = 0
var current_level:String = "res://Resources/Levels/Big_Dawg.tres"
var pending_auto_instant_dive: bool = false
var use_snap_turn = false
var skip_cinematic_intro: bool = false
var vignette = 0.2
static var language_names: Dictionary = {
	Language.ENGLISH: "English",
	Language.SPANISH: "Español",
	Language.FRENCH: "Français",
	Language.GERMAN: "Deutsch",
	Language.RUSSIAN: "Русский"
}

var active_powers = []
var waves:Waves

@onready var underseaPP:Environment = preload("res://Resources/UnderWaterEnvironment.tres")
@onready var temp_variation = randf_range(-5.0,5.0)

signal on_settings_update
signal on_powers_update

func _ready() -> void:
	super()
	add_to_group("GameSettings")
	call_deferred("_connect_session_manager")
	SaveLoad.read_from_file()
	SaveLoad.restore_all()
	apply_settings()
	# Reset the random seed for everything
	randomize()
	update_localized_elements()

func activate_power(itemID):
	if itemID not in active_powers:
		active_powers.append(itemID)
	on_powers_update.emit()

func de_activate_power(itemID):
	if itemID in active_powers:
		active_powers.erase(itemID)
	on_powers_update.emit()

func is_power_active(powerID)->bool:
	return powerID in active_powers

func push_vignette_to_player() -> void:
	var player_root = get_tree().get_first_node_in_group("Player")
	if player_root == null:
		return
	var psm := player_root.get_node_or_null("../PlayerStateMachine") as PlayerStateMachine
	if psm:
		psm.set_vignette_strength(vignette)

func apply_settings():
	_update_reef_driven_environment_settings()
	waves = get_tree().get_first_node_in_group("Waves") as Waves
	if waves:
		waves.wave_amplitude = wave_intensity
		waves.sync_settings()
	var player_root = get_tree().get_first_node_in_group("Player")
	if player_root:
		var player := player_root.get_node_or_null("../PlayerStateMachine") as PlayerStateMachine
		if player:
			player.set_turn_mode(use_snap_turn)
	push_vignette_to_player()
	underseaPP.fog_depth_curve=visibility
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_volume)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), ambience_volume)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"),voice_volume)
	on_settings_update.emit()
	update_localized_elements()

func _update_reef_driven_environment_settings() -> void:
	reef_health = get_current_reef_health()
	visibility = lerpf(MURKY_REEF_FOG_DEPTH_CURVE, CLEAR_REEF_FOG_DEPTH_CURVE, reef_health)

func get_current_reef_health() -> float:
	var level := get_current_level_data()
	if level == null:
		return 0.0
	var manager := get_tree().root.get_node_or_null("SessionManager")
	if manager != null and manager.has_method("get_wreck_reef_health"):
		return manager.get_wreck_reef_health(level.nameID, level)
	return 0.0

func get_current_fish_biomass_ratio() -> float:
	var level := get_current_level_data()
	if level == null:
		return 0.0
	var manager := get_tree().root.get_node_or_null("SessionManager")
	if manager != null and manager.has_method("get_wreck_fish_biomass_ratio"):
		return manager.get_wreck_fish_biomass_ratio(level.nameID, level)
	return 0.0

func get_current_level_data() -> LevelData:
	var level := load(current_level) as LevelData
	return level

func _connect_session_manager() -> void:
	var manager := get_tree().root.get_node_or_null("SessionManager")
	if manager == null or not manager.has_signal("wreck_visuals_changed"):
		return
	var callback := Callable(self, "_on_wreck_visuals_changed")
	if not manager.is_connected("wreck_visuals_changed", callback):
		manager.connect("wreck_visuals_changed", callback)

func _on_wreck_visuals_changed(wreck_id: String) -> void:
	var level := get_current_level_data()
	if level == null or level.nameID != wreck_id:
		return
	apply_settings()

func update_localized_elements():
	print("Updating all localized elements")
	for element in get_tree().get_nodes_in_group("LocalizedElement"):
		print(element.name)
		if element.has_method("get_language_setting"):
			element.get_language_setting()
		if element.has_method("set_text_value"):
			print("Trying to set text value")
			element.set_text_value()

func get_state()->Dictionary:
	return {
		"is_free_play":is_free_play,
		"ocean_currents":str(ocean_currents),
		"wave_intensity":wave_intensity,
		"sfx_volume":sfx_volume,
		"ambience_volume":ambience_volume,
		"voice_volume":voice_volume,
		"max_fish":max_fish,
		"language":language,
		"active_powers":active_powers,
		"current_level":current_level,
		"use_snap_turn":use_snap_turn,
		"vignette":vignette,
		"switch_hands":switch_hands,
		"amateur_mode":amateur_mode,
		"skip_cinematic_intro":skip_cinematic_intro
	}

func restore_state(data: Dictionary):
	ocean_currents = string_to_vector2(data.get("ocean_currents", ocean_currents))
	wave_intensity = data.get("wave_intensity", wave_intensity)
	sfx_volume = data.get("sfx_volume", sfx_volume)
	ambience_volume = data.get("ambience_volume", ambience_volume)
	voice_volume = data.get("voice_volume", voice_volume)
	language = data.get("language", language)
	current_level = data.get("current_level",current_level)
	use_snap_turn = data.get("use_snap_turn",use_snap_turn)
	vignette=data.get("vignette",vignette)
	switch_hands=data.get("switch_hands",switch_hands)
	amateur_mode=data.get("amateur_mode",amateur_mode)
	skip_cinematic_intro=data.get("skip_cinematic_intro",skip_cinematic_intro)
	on_powers_update.emit()

func string_to_vector2(s):
	# Remove parentheses and whitespace
	s = s.strip_edges().replace("(", "").replace(")", "")
	var parts = s.split(",")
	
	if parts.size() != 2:
		push_error("Invalid Vector2 string: " + s)
		return Vector2.ZERO
	
	return Vector2(parts[0].to_float(), parts[1].to_float())
