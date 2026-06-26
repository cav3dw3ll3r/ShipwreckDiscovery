extends Label

func _ready() -> void:
	text = get_environment_version_string()

func get_environment_version_string() -> String:
	# 1. Check if running inside the Godot Editor
	if OS.has_feature("editor"):
		return "SAUCE"
	
	# 2. Check if running on Android/Meta Quest hardware
	elif OS.has_feature("android"):
		# Godot bakes the export preset's Version Name into the config version for the build
		var android_version: String = ProjectSettings.get_setting("application/config/version")
		return android_version if not android_version.is_empty() else "unknown_quest_build"
	
	# 3. Fallback to PC / Desktop standalone builds
	else:
		var pc_version: String = ProjectSettings.get_setting("application/config/version")
		return pc_version if not pc_version.is_empty() else "unknown_pc_build"
