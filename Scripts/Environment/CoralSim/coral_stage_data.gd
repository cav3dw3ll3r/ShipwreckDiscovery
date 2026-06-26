extends Resource
class_name CoralStageData

@export var local_position: Vector3
@export var rotation_y: float
@export var scale_seed: float


func to_dict() -> Dictionary:
	return {
		"pos": var_to_str(local_position),
		"rot": rotation_y,
		"scale": scale_seed,
	}


static func from_dict(data: Dictionary) -> CoralStageData:
	var stage := CoralStageData.new()
	stage.local_position = str_to_var(data["pos"])
	stage.rotation_y = data["rot"]
	stage.scale_seed = data["scale"]
	return stage
