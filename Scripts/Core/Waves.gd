extends Node
class_name Waves

# ==========================================
# PUBLIC API VARIABLES
# Declared so external scripts don't crash when asking for them
# ==========================================
@export var wave_amplitude: float = 1.0
@export var splash_speed: float = 12.0

var push_force = Vector2(0,0)

var wave_length: float = 0.1
var wave_speed: float = 2.0
var wave_count: int = 3
var wave_time: float = 0.0
var active: bool = true

# ==========================================
# INITIALIZATION
# ==========================================
func _ready() -> void:
	# Crucial: Ensures get_tree().get_first_node_in_group("Waves") works
	add_to_group("Waves")
	
	# We can leave the LOD connection here as it is purely structural
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_signal("submersion_level_changed"):
		player.submersion_level_changed.connect(set_LOD)

func _process(delta: float) -> void:
	if not active: return
	wave_time += delta

# ==========================================
# REQUIRED API METHODS (The Safe Harbor)
# ==========================================
func getWaveHeight(x: float, z: float) -> float:
	# Until we rebuild the math, the ocean is perfectly calm.
	return 0.0

func create_splash(posX: float, posZ: float, intensity: float) -> void:
	# Awaiting implementation
	pass

func getSplashHeight() -> float:
	# Awaiting implementation
	return 0.0

func sync_settings() -> void:
	# Awaiting implementation
	pass

func set_LOD(level: int) -> void:
	active = (level < 2)
