extends Control
class_name GlovesPanel

signal on_equip

@export_file var string_table

@onready var purchaseButton:LocalizedButton=$HBoxContainer/LocalizedButton
@onready var name_label:LocalizedLabel = $HBoxContainer/VBoxContainer/Name
@onready var description_label:LocalizedLabel=$HBoxContainer/VBoxContainer/Description
@onready var cost_value_label:Label=$MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/CostValue
@onready var icon:TextureRect = $HBoxContainer/TextureRect

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

func apply_texture(shop_item:ShopItem):
	while not icon:
		await get_tree().process_frame
	icon.texture = shop_item.item_texture

func equip_bound_item():
	if not item: return
	on_equip.emit()
