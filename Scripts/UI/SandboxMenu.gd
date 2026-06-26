extends Control

var all_options_path = "res://Resources/SandboxOptions/"
@onready var not_collected_UI = preload("res://Prefabs/UI/not_collected_placeholder.tscn")
@onready var option_UI = preload("res://Prefabs/UI/sandbox_option.tscn")
@onready var option_container = $ScrollContainer/ProducedBy/Container/MarginContainer/VBoxContainer
var game_settings:GameSettings

func _ready():
	# Get the list of preloaded option resources
	var preloader = $OptionPreloader
