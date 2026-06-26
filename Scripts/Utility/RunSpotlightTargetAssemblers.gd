extends Node

# Headless verification helper.
# Loads each assembler template scene, sets `run = true` to trigger `_assemble()`,
# then quits the app. Intended to be run via the Godot console binary:
#   Shipwreck Discovery.console.exe --headless -s res://Scripts/Utility/RunSpotlightTargetAssemblers.gd

@export var assembler_scenes: Array[String] = [
	"res://Builders/BrannonDylanAssembler.tscn",
	"res://Builders/MonicaLeeAssembler.tscn",
	"res://Builders/MissNellieAssembler.tscn",
	"res://Builders/MissJoannAssembler.tscn",
]

func _ready() -> void:
	for scene_path in assembler_scenes:
		var ps := load(scene_path) as PackedScene
		if ps == null:
			push_error("RunSpotlightTargetAssemblers: Failed to load: %s" % scene_path)
			continue

		var inst := ps.instantiate()
		if inst == null:
			push_error("RunSpotlightTargetAssemblers: Failed to instantiate: %s" % scene_path)
			continue

		add_child(inst)

		# The SpotlightTargetAssembler script has an exported property `run` with a setter.
		inst.set("run", true)

		# Free wrapper root so we don't keep lots of nodes around.
		inst.queue_free()

	# Allow any resource saves to flush before quitting.
	await get_tree().process_frame
	get_tree().quit()

