## DEPRECATED: Not used in Optimized_Base / going forward; kept for reference.
extends Panel

class_name SandboxOptionPanel

@onready var icon:TextureRect = $MarginContainer/VBoxContainer/TextureRect
@onready var nameLabel:LocalizedLabel = $MarginContainer/VBoxContainer/Label
@onready var toggleButton:TextureButton = $MarginContainer/VBoxContainer/TextureButton

var uncheckedTex = preload("res://Resources/Stylesheets/UI_Components/Component01/CheckboxCyan_Off.png")
var checkedTex = preload("res://Resources/Stylesheets/UI_Components/Component01/CheckboxCyan_On.png")

var assignedResource:ShopItem

var active:bool
var sandbox:Node3D

func _ready() -> void:
	sandbox = get_tree().get_first_node_in_group("Sandbox")
	apply_resource(assignedResource)

func apply_resource(sandbox_option):
	assignedResource = sandbox_option
	
	icon.texture = assignedResource.item_texture
	nameLabel.stringTablePath = assignedResource.string_table
	nameLabel.stringID = assignedResource.get_string_IDs()["Name"]
	nameLabel.update()

func on_toggle():
	if(active):
		deactivate()
	else:
		activate()

func activate():
	active = true
	toggleButton.texture_normal = checkedTex
	var spawned = assignedResource.associated_prefab.instantiate()
	spawned.name = assignedResource.itemID
	sandbox.add_child(spawned)

func deactivate():
	active = false
	toggleButton.texture_normal = uncheckedTex
	for child in sandbox.get_children():
		if(child.name == assignedResource.itemID):
			child.queue_free()
