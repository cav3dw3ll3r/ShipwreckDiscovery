extends Resource
class_name CoralData

enum CoralType { BRAIN, STAGHORN, ELKHORN }

@export var global_position: Vector3
@export var baby_stage: CoralStageData
@export var growing_stage: CoralStageData
@export var pristine_stage: CoralStageData
@export var biomass: float
@export var resilience: float
@export var type: CoralType


func get_stage_for_biomass(biomass_value: float) -> CoralStageData:
	if biomass_value < 30.0:
		return baby_stage
	elif biomass_value < 85.0:
		return growing_stage
	return pristine_stage


func to_dict() -> Dictionary:
	return {
		"pos": var_to_str(global_position),
		"biomass": biomass,
		"resilience": resilience,
		"type": type,
		"baby": baby_stage.to_dict() if baby_stage else {},
		"growing": growing_stage.to_dict() if growing_stage else {},
		"pristine": pristine_stage.to_dict() if pristine_stage else {},
	}


static func from_dict(data: Dictionary) -> CoralData:
	var cd := CoralData.new()
	cd.global_position = str_to_var(data["pos"])
	cd.biomass = data["biomass"]
	cd.resilience = data["resilience"]
	cd.type = data["type"]

	if data.has("baby"):
		cd.baby_stage = CoralStageData.from_dict(data["baby"])
		cd.growing_stage = CoralStageData.from_dict(data["growing"])
		cd.pristine_stage = CoralStageData.from_dict(data["pristine"])
	else:
		var legacy_stage := CoralStageData.new()
		legacy_stage.local_position = Vector3.ZERO
		legacy_stage.rotation_y = data.get("rot", 0.0)
		legacy_stage.scale_seed = data.get("scale", 1.0)
		cd.baby_stage = legacy_stage
		cd.growing_stage = legacy_stage.duplicate(true)
		cd.pristine_stage = legacy_stage.duplicate(true)

	return cd
