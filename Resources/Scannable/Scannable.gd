extends Resource

class_name Scannable

enum ScanType
{
	CREATURE,
	RELIC,
	WRECK,
	SUPPORTER,
}

@export_file("*.tsv") var dataPath
@export_dir var iconDir
@export_dir var videoDir = "res://Resources/Scannable/Creatures/videos/"
@export var scannable_type:ScanType
@export var scannable_ID:String
@export var scan_thresholds:Dictionary[int,int]
@export var required_scan_time:float=1.0
@export var scan_prefab:PackedScene
@export var scan_audio:AudioStream
@export_dir var subtitle_dir
