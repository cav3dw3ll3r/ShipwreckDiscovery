extends MarginContainer

var game_settings: GameSettings
var is_dirty: bool = false

@onready var SFXQuickSound = preload("res://Prefabs/ClickSoundPlayer.tscn")
@onready var VoiceQuickSound = preload("res://Prefabs/VoiceSoundPlayer.tscn")

# UI Elements
@onready var languageOptionButton: OptionButton = $ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/OptionButton
@onready var sfx_slider: HSlider = $ScrollContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/SFX
@onready var ambience_slider: HSlider = $ScrollContainer/VBoxContainer/HBoxContainer2/VBoxContainer/Ambience
@onready var voice_slider: HSlider = $ScrollContainer/VBoxContainer/HBoxContainer2/VBoxContainer3/Voice
@onready var applyButton: Button = $ScrollContainer/VBoxContainer/HBoxContainer6/Apply
@onready var cancelButton: Button = $ScrollContainer/VBoxContainer/HBoxContainer6/Cancel
@onready var snapToggle: CheckBox = $ScrollContainer/VBoxContainer/Comfort/SnapTurn
@onready var muteToggle: CheckBox = $ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CheckButton
@onready var vignette_slider: HSlider = $ScrollContainer/VBoxContainer/Comfort/Vignette
@onready var amateur_mode_toggle: CheckBox = $ScrollContainer/VBoxContainer/Controls/AmateurMode
@onready var switch_hands_toggle: CheckBox = $ScrollContainer/VBoxContainer/Controls/SwitchHands

func _ready() -> void:
	game_settings = get_tree().get_first_node_in_group("GameSettings")

	setupLanguageSettings()

	connect_signals()

	restoreFromSettings()
	set_dirty(false)

func connect_signals() -> void:
	languageOptionButton.item_selected.connect(changeLanguageSetting)

	sfx_slider.value_changed.connect(setSFXVolume)
	ambience_slider.value_changed.connect(setAmbienceVolume)
	voice_slider.value_changed.connect(setVoiceVolume)
	vignette_slider.value_changed.connect(set_vignette)

	if applyButton:
		applyButton.pressed.connect(apply)
	if cancelButton:
		cancelButton.pressed.connect(cancel)
	if snapToggle:
		snapToggle.toggled.connect(onSnapToggle)
	if muteToggle:
		muteToggle.toggled.connect(onMute)
	amateur_mode_toggle.toggled.connect(_on_amateur_mode_toggled)
	switch_hands_toggle.toggled.connect(_on_switch_hands_toggled)

# ---------------------------------------------------
# Dirty state handling
# ---------------------------------------------------

func set_dirty(new_val: bool) -> void:
	is_dirty = new_val
	cancelButton.visible = is_dirty
	applyButton.visible = is_dirty

# ---------------------------------------------------
# Apply / Cancel
# ---------------------------------------------------

func apply() -> void:
	SaveLoad.save_all()
	SaveLoad.write_to_file()
	game_settings.apply_settings()
	set_dirty(false)

func cancel() -> void:
	SaveLoad.restore_all()
	restoreFromSettings()
	game_settings.apply_settings()
	set_dirty(false)

# ---------------------------------------------------
# Restore
# ---------------------------------------------------

func restoreFromSettings() -> void:
	languageOptionButton.select(game_settings.language)

	sfx_slider.set_value_no_signal(game_settings.sfx_volume)
	ambience_slider.set_value_no_signal(game_settings.ambience_volume)
	voice_slider.set_value_no_signal(game_settings.voice_volume)
	vignette_slider.set_value_no_signal(game_settings.vignette)
	snapToggle.set_pressed_no_signal(game_settings.use_snap_turn)
	muteToggle.set_pressed_no_signal(game_settings.mute_videos)
	amateur_mode_toggle.set_pressed_no_signal(game_settings.amateur_mode)
	switch_hands_toggle.set_pressed_no_signal(game_settings.switch_hands)

# ---------------------------------------------------
# Audio
# ---------------------------------------------------

func setVoiceVolume(newSetting: float) -> void:
	game_settings.voice_volume = newSetting
	game_settings.apply_settings()
	add_child(VoiceQuickSound.instantiate())
	set_dirty(true)

func setSFXVolume(newSetting: float) -> void:
	game_settings.sfx_volume = newSetting
	game_settings.apply_settings()
	add_child(SFXQuickSound.instantiate())
	set_dirty(true)

func setAmbienceVolume(newSetting: float) -> void:
	game_settings.ambience_volume = newSetting
	game_settings.apply_settings()
	set_dirty(true)

func onSnapToggle(use_snap: bool) -> void:
	game_settings.use_snap_turn = use_snap
	set_dirty(true)

func onMute(is_muted: bool) -> void:
	game_settings.mute_videos = is_muted
	set_dirty(true)

func _on_amateur_mode_toggled(enabled: bool) -> void:
	game_settings.amateur_mode = enabled
	set_dirty(true)

func _on_switch_hands_toggled(enabled: bool) -> void:
	game_settings.switch_hands = enabled
	set_dirty(true)

# ---------------------------------------------------
# Language
# ---------------------------------------------------

func changeLanguageSetting(selectedIndex: int) -> void:
	game_settings.language = selectedIndex as GameSettings.Language
	game_settings.apply_settings()
	set_dirty(true)

func setupLanguageSettings() -> void:
	languageOptionButton.clear()

	for key in GameSettings.language_names.keys():
		var language_name := str(GameSettings.language_names[key])
		if language_name != "":
			languageOptionButton.add_item(language_name)

	var current_language := game_settings.language
	if current_language in GameSettings.language_names.keys():
		var current_index := GameSettings.language_names.keys().find(current_language)
		languageOptionButton.select(current_index)

func set_vignette(new_val: float) -> void:
	game_settings.vignette = new_val
	game_settings.push_vignette_to_player()
	set_dirty(true)
