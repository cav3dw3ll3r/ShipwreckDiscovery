extends Control
class_name PowersPanel

signal on_equip

@export_file var string_table

@onready var name_label:LocalizedLabel = $HBoxContainer/VBoxContainer/Name
@onready var description_label:LocalizedLabel=$HBoxContainer/VBoxContainer/Description
@onready var cost_value_label:Label=$MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/CostValue
@onready var icon:TextureRect = $HBoxContainer/TextureRect
@onready var toggle_button:CheckBox = $HBoxContainer/LocalizedButton/CheckButton
@onready var game_settings:GameSettings = get_tree().get_first_node_in_group("GameSettings")

var item:ShopItem

func assign_shop_item(shop_item:ShopItem) -> void:
	item = shop_item
	name_label.stringTablePath = shop_item.string_table
	var ids = shop_item.get_string_IDs()
	name_label.stringID = ids["Name"]
	name_label.update()
	description_label.stringTablePath = shop_item.string_table
	description_label.stringID=ids["Description"]
	description_label.update()
	icon.texture = shop_item.item_texture
	toggle_button.set_pressed_no_signal(game_settings.is_power_active(shop_item.itemID))

func apply_texture(shop_item:ShopItem):
	while not icon:
		await get_tree().process_frame
	icon.texture = shop_item.item_texture

func toggle_item(value):
	if not item: return
	if value:
		game_settings.activate_power(item.itemID)
	else:
		game_settings.de_activate_power(item.itemID)
	on_equip.emit()
