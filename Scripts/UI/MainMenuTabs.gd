extends Node

class_name MainMenuTabs

@export var TravelButton: LocalizedButton
@export var CreditShopButton:LocalizedButton
@export var PlayerMenuButton:LocalizedButton
@export var DiveLogButton: LocalizedButton
@export var SettingsButton: LocalizedButton
@export var CreditsButton: LocalizedButton
@export var ExitButton: LocalizedButton
@export var TutorialButton: LocalizedButton
@export var ContextMenuContainer: Container
@export var LoginOverrideContainer: Control
@export var LoginOverrideContentContainer: Container
@export var LoginOverrideBackButton: Button

#@onready var DiveNowMenu = preload()
@onready var TravelMenu = preload("res://Prefabs/UI/travel_menu.tscn")
@onready var DiveLogMenu = preload("res://Prefabs/UI/dive_log_placeholder.tscn")
@onready var TutorialMenu = preload("res://Prefabs/UI/tutorial_menu.tscn")
@onready var CreditShopMenu
@onready var SettingsMenu = preload("res://Prefabs/UI/settings_menu.tscn")
@onready var CreditsMenu = preload("res://Prefabs/UI/credits_menu.tscn")
@onready var ExitMenu = preload("res://Prefabs/UI/exit_menu.tscn")
@onready var NewPlayerGuide = preload("res://Prefabs/UI/new_player_guide.tscn")
@onready var StatusReport = preload("res://Prefabs/UI/status_report.tscn")
@onready var DiveInProgress = preload("res://Prefabs/UI/dive_in_progress.tscn")
@onready var DiveSummary = preload("res://Prefabs/UI/dive_summary.tscn")
@onready var normal_menu_container: Control = $HBoxContainer

@onready var current_context_menu: Node
@onready var current_login_override: Node

var last_scanned

func _ready() -> void:
	TravelButton.pressed.connect(func(): open_context_menu(TravelMenu))
	DiveLogButton.pressed.connect(func(): open_context_menu(DiveLogMenu))
	CreditShopButton.pressed.connect(func(): open_context_menu(CreditShopMenu))
	TutorialButton.pressed.connect(func(): open_context_menu(TutorialMenu))
	SettingsButton.pressed.connect(func(): open_context_menu(SettingsMenu))
	CreditsButton.pressed.connect(func(): open_context_menu(CreditsMenu))
	ExitButton.pressed.connect(func(): open_context_menu(ExitMenu))
	LoginOverrideBackButton.pressed.connect(dismiss_login_override)
	SignalBus.dive_started.connect(_on_dive_started)
	SignalBus.dive_completed.connect(_on_dive_completed)
	open_context_menu(TravelMenu)
	await get_tree().process_frame
	_show_startup_override()

func open_context_menu(menu_scene: PackedScene) -> void:
	# Remove existing context menu if there is one
	if current_context_menu and is_instance_valid(current_context_menu):
		current_context_menu.queue_free()

	# Create new context menu and add it to the container
	current_context_menu = menu_scene.instantiate()
	ContextMenuContainer.add_child(current_context_menu)
	if(current_context_menu.has_method("add_dynamic_scan_content")):
		current_context_menu.add_dynamic_scan_content(last_scanned)


func show_login_override(override_scene: PackedScene, show_back_button: bool = true) -> void:
	_clear_login_override_content()
	current_login_override = override_scene.instantiate()
	LoginOverrideContentContainer.add_child(current_login_override)

	if current_login_override is Control:
		var override_control := current_login_override as Control
		override_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		override_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		override_control.size_flags_vertical = Control.SIZE_EXPAND_FILL

	normal_menu_container.visible = false
	LoginOverrideBackButton.visible = show_back_button
	LoginOverrideContainer.visible = true


func dismiss_login_override() -> void:
	_clear_login_override_content()
	if current_context_menu and is_instance_valid(current_context_menu) and current_context_menu.has_method("refresh_display"):
		current_context_menu.refresh_display()
	LoginOverrideContainer.visible = false
	normal_menu_container.visible = true


func _show_startup_override() -> void:
	if SessionManager.is_dive_active():
		show_login_override(DiveInProgress, false)
	elif SessionManager.has_completed_dive():
		show_login_override(StatusReport)
	else:
		show_login_override(NewPlayerGuide)


func _on_dive_started(_wreck_id: String) -> void:
	show_login_override(DiveInProgress, false)


func _on_dive_completed(_wreck_id: String, _dive_report: Dictionary) -> void:
	show_login_override(DiveSummary)
	if current_login_override and current_login_override.has_method("setup"):
		current_login_override.setup(_wreck_id, _dive_report)


func _clear_login_override_content() -> void:
	for child in LoginOverrideContentContainer.get_children():
		LoginOverrideContentContainer.remove_child(child)
		child.queue_free()
	current_login_override = null
