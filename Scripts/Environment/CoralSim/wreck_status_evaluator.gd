extends RefCounted
class_name WreckStatusEvaluator

enum StatusSeverity { GOOD, CAUTION, DANGER }

const SEVERITY_COLORS: Dictionary = {
	StatusSeverity.GOOD: Color(0.45, 0.92, 0.55),
	StatusSeverity.CAUTION: Color(0.98, 0.84, 0.32),
	StatusSeverity.DANGER: Color(0.95459753, 0.37162954, 0.37798268),
}

const STATUS_SEVERITY: Dictionary = {
	"WreckStatus_Healthy": StatusSeverity.GOOD,
	"WreckStatus_Pristine": StatusSeverity.GOOD,
	"WreckStatus_FishReturning": StatusSeverity.GOOD,
	"WreckStatus_CoralGrowing": StatusSeverity.CAUTION,
	"WreckStatus_SterilePlantCoral": StatusSeverity.CAUTION,
	"WreckStatus_FishDecliningPlantCoral": StatusSeverity.CAUTION,
	"WreckStatus_PollutedClearTrash": StatusSeverity.CAUTION,
	"WreckStatus_TrashedCleanUp": StatusSeverity.DANGER,
	"WreckStatus_InfestedCullLionfish": StatusSeverity.DANGER,
	"WreckStatus_NeglectedPlantCoral": StatusSeverity.DANGER,
	"WreckStatus_NeglectedCullLionfish": StatusSeverity.DANGER,
	"WreckStatus_NeglectedCleanUp": StatusSeverity.DANGER,
	"WreckStatus_CriticalEcosystemDying": StatusSeverity.DANGER,
}

# Indexed by lionfish * 27 + trash * 9 + coral * 3 + fish
const TRUTH_TABLE: Array[String] = [
	# lf=0 trash=0
	"WreckStatus_SterilePlantCoral", "WreckStatus_FishDecliningPlantCoral", "WreckStatus_FishDecliningPlantCoral",
	"WreckStatus_CoralGrowing", "WreckStatus_CoralGrowing", "WreckStatus_FishDecliningPlantCoral",
	"WreckStatus_FishReturning", "WreckStatus_Healthy", "WreckStatus_Pristine",
	# lf=0 trash=1
	"WreckStatus_PollutedClearTrash", "WreckStatus_FishDecliningPlantCoral", "WreckStatus_FishDecliningPlantCoral",
	"WreckStatus_PollutedClearTrash", "WreckStatus_PollutedClearTrash", "WreckStatus_FishDecliningPlantCoral",
	"WreckStatus_FishReturning", "WreckStatus_FishReturning", "WreckStatus_Pristine",
	# lf=0 trash=2
	"WreckStatus_TrashedCleanUp", "WreckStatus_TrashedCleanUp", "WreckStatus_TrashedCleanUp",
	"WreckStatus_TrashedCleanUp", "WreckStatus_TrashedCleanUp", "WreckStatus_TrashedCleanUp",
	"WreckStatus_TrashedCleanUp", "WreckStatus_TrashedCleanUp", "WreckStatus_TrashedCleanUp",
	# lf=1 trash=0
	"WreckStatus_SterilePlantCoral", "WreckStatus_SterilePlantCoral", "WreckStatus_SterilePlantCoral",
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	# lf=1 trash=1
	"WreckStatus_NeglectedPlantCoral", "WreckStatus_NeglectedPlantCoral", "WreckStatus_NeglectedPlantCoral",
	"WreckStatus_NeglectedCullLionfish", "WreckStatus_NeglectedCullLionfish", "WreckStatus_NeglectedCullLionfish",
	"WreckStatus_NeglectedCullLionfish", "WreckStatus_NeglectedCullLionfish", "WreckStatus_NeglectedCullLionfish",
	# lf=1 trash=2
	"WreckStatus_NeglectedCleanUp", "WreckStatus_NeglectedCleanUp", "WreckStatus_NeglectedCleanUp",
	"WreckStatus_NeglectedCleanUp", "WreckStatus_NeglectedCleanUp", "WreckStatus_NeglectedCleanUp",
	"WreckStatus_NeglectedCleanUp", "WreckStatus_NeglectedCleanUp", "WreckStatus_NeglectedCleanUp",
	# lf=2 trash=0
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	# lf=2 trash=1
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	"WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish", "WreckStatus_InfestedCullLionfish",
	# lf=2 trash=2
	"WreckStatus_CriticalEcosystemDying", "WreckStatus_CriticalEcosystemDying", "WreckStatus_CriticalEcosystemDying",
	"WreckStatus_CriticalEcosystemDying", "WreckStatus_CriticalEcosystemDying", "WreckStatus_CriticalEcosystemDying",
	"WreckStatus_CriticalEcosystemDying", "WreckStatus_CriticalEcosystemDying", "WreckStatus_CriticalEcosystemDying",
]


static func evaluate(state: Dictionary, blueprint: LevelData) -> Dictionary:
	var lionfish_count: int = state.get("lionfish_present", 0)
	var trash_coverage: float = state.get("trash_coverage", 0.0)
	var fish_biomass: float = state.get("fish_biomass", 0.0)
	var corals: Dictionary = state.get("corals", {})

	var coral_biomass := sum_coral_biomass(corals)
	var target_biomass: float = blueprint.target_biomass

	var lf_rating := lionfish_rating(lionfish_count)
	var trash_rating_value := trash_rating(trash_coverage)
	var coral_rating := biomass_rating(coral_biomass, target_biomass)
	var fish_rating := biomass_rating(fish_biomass, target_biomass)

	var status_string_id := get_status_string_id(lf_rating, trash_rating_value, coral_rating, fish_rating)
	var reef_health := calculate_reef_health(state, blueprint)

	return {
		"status_string_id": status_string_id,
		"status_severity": get_severity_for_status(status_string_id),
		"lionfish": lionfish_count,
		"trash": trash_coverage,
		"coral_biomass": coral_biomass,
		"fish_biomass": fish_biomass,
		"reef_health": reef_health,
		"reef_health_percent": reef_health * 100.0,
		"coral_tier_counts": count_coral_tiers(corals),
	}


static func calculate_reef_health(state: Dictionary, blueprint: LevelData) -> float:
	if blueprint == null or blueprint.target_biomass <= 0.0:
		return 0.0
	var corals: Dictionary = state.get("corals", {})
	var coral_biomass := sum_coral_biomass(corals)
	var fish_biomass: float = state.get("fish_biomass", 0.0)
	var target_total := blueprint.target_biomass * 2.0
	return clampf((coral_biomass + fish_biomass) / target_total, 0.0, 1.0)


static func sum_coral_biomass(corals: Dictionary) -> float:
	var total := 0.0
	for coral in corals.values():
		total += coral.get("biomass", 0.0)
	return total


static func count_coral_tiers(corals: Dictionary) -> Array[int]:
	var baby := 0
	var growing := 0
	var pristine := 0
	for coral in corals.values():
		var biomass: float = coral.get("biomass", 0.0)
		if biomass < 30.0:
			baby += 1
		elif biomass < 85.0:
			growing += 1
		else:
			pristine += 1
	return [baby, growing, pristine]


static func biomass_rating(current: float, target: float) -> int:
	if target <= 0.0:
		return 0
	var percent := current / target * 100.0
	if percent < 20.0:
		return 0
	if percent < 85.0:
		return 1
	return 2


static func lionfish_rating(count: int) -> int:
	if count <= 10:
		return 0
	if count <= 40:
		return 1
	return 2


static func trash_rating(coverage: float) -> int:
	if coverage < 0.25:
		return 0
	if coverage < 0.75:
		return 1
	return 2


static func get_status_string_id(lf: int, trash: int, coral: int, fish: int) -> String:
	var index := lf * 27 + trash * 9 + coral * 3 + fish
	if index < 0 or index >= TRUTH_TABLE.size():
		push_warning("WreckStatusEvaluator: Invalid truth table index %d" % index)
		return "WreckStatus_SterilePlantCoral"
	return TRUTH_TABLE[index]


static func get_severity_for_status(status_string_id: String) -> StatusSeverity:
	return STATUS_SEVERITY.get(status_string_id, StatusSeverity.CAUTION)


static func get_severity_color(severity: StatusSeverity) -> Color:
	return SEVERITY_COLORS.get(severity, SEVERITY_COLORS[StatusSeverity.CAUTION])
