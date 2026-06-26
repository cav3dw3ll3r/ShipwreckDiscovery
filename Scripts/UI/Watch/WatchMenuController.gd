extends Node

@onready var hp_bar = $HPBar
@onready var air_bar = $AirBar

var player_state_machine:PlayerStateMachine

func _ready() -> void:
	call_deferred("setup_callbacks")
	player_state_machine = get_tree().get_first_node_in_group("Player").get_parent().get_node("PlayerStateMachine")
	player_state_machine.damage_event.connect(update_health)
	player_state_machine.air_event.connect(update_air)
	
func setup_callbacks():
	if SignalBus and not SignalBus.on_coin_earned.is_connected(update_coins):
		SignalBus.on_coin_earned.connect(update_coins)

func update_coins(_amount: int = 0, _balance: int = 0):
	pass

func update_health():
	hp_bar.value = player_state_machine.remainingHealth/player_state_machine.maxHealth

func update_air():
	air_bar.value = player_state_machine.remainingAir/player_state_machine.maxAir
