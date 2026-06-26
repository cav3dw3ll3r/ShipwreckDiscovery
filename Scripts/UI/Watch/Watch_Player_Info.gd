extends Control

var previous:PackedScene = preload("res://Prefabs/UI/WatchSubMenus/top_level_menu.tscn")

@onready var back_button:Button = $VBoxContainer/Back
@onready var coinsValue:Label = $VBoxContainer/Coins/Value

@onready var progressValue = $VBoxContainer/Progress/Value

func _ready() -> void:
	back_button.pressed.connect(on_back)
	if not SignalBus.on_coin_earned.is_connected(on_coin):
		SignalBus.on_coin_earned.connect(on_coin)
	coinsValue.text = str(SessionManager.get_reefcoin())
	progressValue.text = "0"

func on_coin(_amount: int = 0, balance: int = 0):
	coinsValue.text = str(balance)

func on_back():
	var spawn = previous.instantiate()
	get_parent().add_child(spawn)
	queue_free()
