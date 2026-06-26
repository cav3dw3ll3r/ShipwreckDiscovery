extends Control
class_name SandboxPanel

signal on_equip

@export_file var string_table

@onready var name_label:LocalizedLabel = $HBoxContainer/VBoxContainer/Name
@onready var description_label:LocalizedLabel=$HBoxContainer/VBoxContainer/Description
@onready var cost_value_label:Label=$MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/CostValue
@onready var icon:TextureRect = $HBoxContainer/TextureRect
@onready var toggle_button:CheckBox = $HBoxContainer/LocalizedButton/CheckButton
@onready var sandbox = get_tree().get_first_node_in_group("Sandbox")

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
	toggle_button.set_pressed_no_signal(is_item_active())

func apply_texture(shop_item:ShopItem):
	while not icon:
		await get_tree().process_frame
	icon.texture = shop_item.item_texture

func toggle_item(value):
	if not item: return
	if value:
		activate()
	else:
		deactivate()
	on_equip.emit()

func is_item_active():
	for child in sandbox.get_children():
		if(child.name == item.itemID):
			return true
	return false

func activate():
	var spawned = item.associated_prefab.instantiate()
	spawned.name = item.itemID
	sandbox.add_child(spawned)

func deactivate():
	for child in sandbox.get_children():
		if(child.name == item.itemID):
			child.queue_free()
