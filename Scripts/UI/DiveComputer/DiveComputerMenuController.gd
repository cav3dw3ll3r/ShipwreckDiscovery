extends MarginContainer

@onready var hp_bar = $VBoxContainer/Header/HPBar
@onready var air_bar = $VBoxContainer/Header/AirBar
@onready var content_holder = $VBoxContainer/ContentPane
@onready var dive_time: Label = $VBoxContainer/Header2/Dive_Time
@onready var reefcoin: Label = $VBoxContainer/Header2/Reefcoin

var player_state_machine: PlayerStateMachine
var temp_rand: float
var time_since_tick := 0.0

const WORLD_SCALE_MULTIPLIER := 0.74
var _active_pane: Node
var _active_dc_pane: DCContentPane
var _pane_stack: Array[DCContentPane] = []
var _on_change_pane: Callable

const INPUT_DEBOUNCE_SEC := 0.3
var _last_pass_through_msec: int = -int(INPUT_DEBOUNCE_SEC * 1000.0)

@export var base_content_pane: PackedScene

func _ready() -> void:
	_on_change_pane = Callable(self, "_handle_change_pane")
	_connect_coin_signals()
	_refresh_reefcoin()
	_refresh_dive_time()

	var player_node := get_tree().get_first_node_in_group("Player")
	if player_node == null:
		push_error("DiveComputerMenuController: Player group node not found")
		return
	player_state_machine = player_node.get_parent().get_node_or_null("PlayerStateMachine") as PlayerStateMachine
	if player_state_machine == null:
		push_error("DiveComputerMenuController: PlayerStateMachine not found")
		return
	player_state_machine.damage_event.connect(update_health)
	player_state_machine.air_event.connect(update_air)
	var game_settings := get_tree().get_first_node_in_group("GameSettings")
	if game_settings != null:
		temp_rand = game_settings.temp_variation
	if base_content_pane != null:
		set_main_content_pane(base_content_pane.instantiate() as DCContentPane, false)

func _exit_tree() -> void:
	if SignalBus.on_coin_earned.is_connected(_on_coin_changed):
		SignalBus.on_coin_earned.disconnect(_on_coin_changed)
	if SignalBus.on_coin_spent.is_connected(_on_coin_changed):
		SignalBus.on_coin_spent.disconnect(_on_coin_changed)

func update_health() -> void:
	hp_bar.value = player_state_machine.remainingHealth / player_state_machine.maxHealth

func update_air() -> void:
	air_bar.value = player_state_machine.remainingAir / player_state_machine.maxAir

func _process(delta: float) -> void:
	if player_state_machine == null:
		return
	time_since_tick += delta
	if time_since_tick >= 0.05:
		time_since_tick = 0.0
		_refresh_dive_time()

func _connect_coin_signals() -> void:
	if not SignalBus.on_coin_earned.is_connected(_on_coin_changed):
		SignalBus.on_coin_earned.connect(_on_coin_changed)
	if not SignalBus.on_coin_spent.is_connected(_on_coin_changed):
		SignalBus.on_coin_spent.connect(_on_coin_changed)

func _on_coin_changed(_amount: int, _balance: int) -> void:
	_refresh_reefcoin()

func _refresh_reefcoin() -> void:
	reefcoin.text = str(SessionManager.get_reefcoin())

func _refresh_dive_time() -> void:
	var elapsed_seconds := SessionManager.get_current_dive_elapsed_seconds()
	var minutes := int(elapsed_seconds / 60)
	var seconds := elapsed_seconds % 60
	dive_time.text = "%02d:%02d" % [minutes, seconds]

func get_temperature(depth_m: float) -> float:
	var surface_temp := 26.0
	var bottom_temp := 18.0
	var thermocline_top := 3.0
	var thermocline_bottom := 45.0

	if depth_m <= thermocline_top:
		return surface_temp + temp_rand
	elif depth_m <= thermocline_bottom:
		var fraction := (depth_m - thermocline_top) / (thermocline_bottom - thermocline_top)
		return lerp(surface_temp, bottom_temp, fraction) + temp_rand
	else:
		return bottom_temp + temp_rand

func to_feet(meters: float) -> float:
	return meters * 3.208

func to_fahrenheit(celsius: float) -> float:
	return (celsius * 1.8) + 32

## PASS THROUGH INTERFACE
func _passes_input_debounce() -> bool:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_pass_through_msec < int(INPUT_DEBOUNCE_SEC * 1000.0):
		return false
	_last_pass_through_msec = now_msec
	return true

func on_prev() -> void:
	if not _passes_input_debounce():
		return
	if _active_dc_pane:
		_active_dc_pane.prev()

func on_accept() -> void:
	if not _passes_input_debounce():
		return
	if _active_dc_pane:
		_active_dc_pane.accept()

func on_next() -> void:
	if not _passes_input_debounce():
		return
	if _active_dc_pane:
		_active_dc_pane.next()

func _handle_change_pane(pane: DCContentPane) -> void:
	call_deferred("set_main_content_pane", pane, true)

func navigate_to_previous() -> void:
	if not _pane_stack.is_empty():
		var previous: DCContentPane = _pane_stack.pop_back()
		set_main_content_pane(previous, false)
	elif base_content_pane != null:
		set_main_content_pane(base_content_pane.instantiate() as DCContentPane, false)

func _disconnect_active_pane() -> void:
	if _active_dc_pane != null and is_instance_valid(_active_dc_pane):
		if _active_dc_pane.change_pane.is_connected(_on_change_pane):
			_active_dc_pane.change_pane.disconnect(_on_change_pane)

func _attach_pane(pane: Node) -> void:
	content_holder.add_child(pane)
	_active_pane = pane
	_active_dc_pane = pane as DCContentPane
	if _active_dc_pane != null and not _active_dc_pane.change_pane.is_connected(_on_change_pane):
		_active_dc_pane.change_pane.connect(_on_change_pane)

## FUNCTIONS TO BE CALLED BY STAGING ONCE IMPLEMENTED
func set_main_content_pane(pane: Node, push_current: bool = true) -> void:
	if pane == null:
		return

	if push_current and _active_dc_pane != null and is_instance_valid(_active_dc_pane):
		_disconnect_active_pane()
		content_holder.remove_child(_active_dc_pane)
		_pane_stack.append(_active_dc_pane)
	else:
		_disconnect_active_pane()
		for c in content_holder.get_children():
			content_holder.remove_child(c)
			c.queue_free()

	_attach_pane(pane)
