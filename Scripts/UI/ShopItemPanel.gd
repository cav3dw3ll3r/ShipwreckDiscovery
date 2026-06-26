extends Control

class_name ShopItemPanel

@export_file var string_table

@onready var purchaseButton:LocalizedButton=$MarginContainer/HBoxContainer/VBoxContainer2/Button
@onready var name_label:LocalizedLabel = $MarginContainer/HBoxContainer/VBoxContainer/Name
@onready var description_label:LocalizedLabel=$MarginContainer/HBoxContainer/VBoxContainer/Description
@onready var cost_value_label:Label=$MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/CostValue
@onready var icon:TextureRect = $MarginContainer/HBoxContainer/TextureRect
const cost_label_id = "CostLabel"
const cost_unit_id = "CostUnits"
const can_purchase_id = "PurchaseButton"
const cant_purchase_id = "NoPurchaseButton"

var item:ShopItem

signal on_purchase

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
	cost_value_label.text = str(shop_item.cost)
	pass

func apply_texture(shop_item:ShopItem):
	while not icon:
		await get_tree().process_frame
	icon.texture = shop_item.item_texture

func purchase_bound_item():
	if not item: return
	on_purchase.emit()
