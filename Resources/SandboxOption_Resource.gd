extends Resource

class_name SandboxOption

# Corresponds to the matching title in the string table as well
@export var optionID:String
@export var optionIcon:Texture
@export_file("*.csv") var stringTablePath:String
@export var spawnPrefab: PackedScene 
