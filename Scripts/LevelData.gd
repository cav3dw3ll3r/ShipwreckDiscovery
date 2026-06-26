extends Resource
class_name LevelData
@export_group("Basic information")
@export var scene_path:String
@export var nameID:String
@export var groupID:String
@export var descriptionID:String
@export_file var stringTable
@export_group("Initial State")
@export var target_biomass: float = 1000
@export var initial_lionfish:int
@export var initial_pollution:float
@export var initial_fish_biomass:float
@export var initial_corals:Array[CoralData]
