extends Control
class_name CreditShop

@onready var creditsValue:Label = $HBoxContainer/Value
@onready var shop_items_list = $ScrollContainer/MarginContainer/ForSale
@onready var purchase_sound_player = $AudioStreamPlayer3D
var player_coins:int
var shop_item_prefab = preload("res://Prefabs/UI/shop_item_panel.tscn")

var filter = "SANDBOX"

func _ready() -> void:
	player_coins = SessionManager.get_reefcoin()
	creditsValue.text = str(player_coins)
	initialize_shop_items()

func on_purchase():
	purchase_sound_player.play()
	player_coins = SessionManager.get_reefcoin()
	creditsValue.text = str(player_coins)
	initialize_shop_items()

func filter_gloves():
	filter = "GLOVE"
	initialize_shop_items()

func filter_powers():
	filter = "POWER"
	initialize_shop_items()

func filter_sandbox():
	filter = "SANDBOX"
	initialize_shop_items()

func initialize_shop_items():
	for node in shop_items_list.get_children():
		node.queue_free()
