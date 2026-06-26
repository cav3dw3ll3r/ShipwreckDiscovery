extends Panel
class_name SupporterListing
@onready var header:RichTextLabel = $HBoxContainer/HBoxContainer/VBoxContainer/RichTextLabel
@onready var description:Label = $HBoxContainer/HBoxContainer/VBoxContainer/Label
@onready var icon:TextureRect = $HBoxContainer/HBoxContainer/TextureRect

func set_supporter_listing_params(name, description, iconPath):
	if(name!=""): header.text = name
	if(description!=""): self.description.text = description
	if(iconPath!=""): icon.texture = load(iconPath)
	
