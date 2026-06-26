@tool
extends MeshInstance3D
class_name DotMatrixDisplay

const MASK_BITS := 0xFFFFFFFF
const GRID_SIZE := 8

const NUMBER_PATTERNS: Array[String] = [
	"........\n...##...\n..###...\n...##...\n...##...\n...##...\n..####..\n........",
	"........\n..####..\n.#....#.\n.....#..\n...##...\n..#.....\n.######.\n........",
	"........\n..####..\n.#....#.\n....##..\n......#.\n.#....#.\n..####..\n........",
	"........\n...#..#.\n..#...#.\n.#....#.\n.######.\n......#.\n......#.\n........",
	"........\n.######.\n.#......\n.#####..\n......#.\n.#....#.\n..####..\n........",
	"........\n...###..\n..#.....\n.#####..\n.#....#.\n.#....#.\n..####..\n........",
	"........\n.######.\n......#.\n.....#..\n....#...\n...#....\n..#.....\n........",
	"........\n..####..\n.#....#.\n..####..\n.#....#.\n.#....#.\n..####..\n........",
]

static func chevron_up_small() -> Vector2i:
	var pattern := \
		"........\n" + \
		"........\n" + \
		"...##...\n" + \
		"..#..#..\n" + \
		".#....#.\n" + \
		"........\n" + \
		"........\n" + \
		"........"
	return _masks_from_pattern(pattern)

static func chevron_down_small() -> Vector2i:
	var pattern := \
		"........\n" + \
		"........\n" + \
		"........\n" + \
		".#....#.\n" + \
		"..#..#..\n" + \
		"...##...\n" + \
		"........\n" + \
		"........"
	return _masks_from_pattern(pattern)

static func chevron_up_double() -> Vector2i:
	var pattern := \
		"........\n" + \
		"...##...\n" + \
		"..#..#..\n" + \
		".#....#.\n" + \
		"...##...\n" + \
		"..#..#..\n" + \
		".#....#.\n" + \
		"........"
	return _masks_from_pattern(pattern)

static func chevron_down_double() -> Vector2i:
	var pattern := \
		"........\n" + \
		".#....#.\n" + \
		"..#..#..\n" + \
		"...##...\n" + \
		".#....#.\n" + \
		"..#..#..\n" + \
		"...##...\n" + \
		"........"
	return _masks_from_pattern(pattern)

@export var mask_upper: int = 0
@export var mask_lower: int = 0

var _material: ShaderMaterial


func _ready() -> void:
	_ensure_material()
	apply()


func _ensure_material() -> void:
	if _material != null:
		return
	var source := get_surface_override_material(0) as ShaderMaterial
	if source == null:
		source = get_active_material(0) as ShaderMaterial
	if source == null:
		push_warning("DotMatrixDisplay: no shader material found on %s" % name)
		return
	_material = source.duplicate() as ShaderMaterial
	set_surface_override_material(0, _material)

var _anim_tween: Tween

func stop_animation() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null

func show_forward_ready() -> void:
	stop_animation()
	var masks := chevron_up_small()
	set_masks(masks.x, masks.y)

func play_idle_animation() -> void:
	stop_animation()
	
	# Create a looping tween bound to this node
	_anim_tween = create_tween().bind_node(self).set_loops()
	
	var single := chevron_up_small()
	var double := chevron_up_double()
	
	# 1. Start with a brief clear state using set_masks so we don't kill the Tween
	_anim_tween.tween_callback(set_masks.bind(0, 0))
	_anim_tween.tween_interval(0.2)
	
	# 2. Show the single chevron briefly
	_anim_tween.tween_callback(set_masks.bind(single.x, single.y))
	_anim_tween.tween_interval(0.2)
	
	# 3. Immediately show the double chevron and hold it longer
	_anim_tween.tween_callback(set_masks.bind(double.x, double.y))
	_anim_tween.tween_interval(0.8)

func set_dot(index: int, on: bool) -> void:
	if not _is_valid_index(index):
		return
	var bit := (index - 1) % 32
	if index <= 32:
		if on:
			mask_upper = (mask_upper | (1 << bit)) & MASK_BITS
		else:
			mask_upper = (mask_upper & ~(1 << bit)) & MASK_BITS
	else:
		if on:
			mask_lower = (mask_lower | (1 << bit)) & MASK_BITS
		else:
			mask_lower = (mask_lower & ~(1 << bit)) & MASK_BITS
	apply()


func get_dot(index: int) -> bool:
	if not _is_valid_index(index):
		return false
	var bit := (index - 1) % 32
	if index <= 32:
		return (mask_upper & (1 << bit)) != 0
	return (mask_lower & (1 << bit)) != 0


func toggle_dot(index: int) -> void:
	set_dot(index, not get_dot(index))

func show_reverse_untangle() -> void:
	stop_animation()
	var masks := chevron_down_small()
	set_masks(masks.x, masks.y)

func show_reverse_fast() -> void:
	stop_animation()
	var masks := chevron_down_double()
	set_masks(masks.x, masks.y)

func set_masks(upper: int, lower: int) -> void:
	mask_upper = upper & MASK_BITS
	mask_lower = lower & MASK_BITS
	apply()


func get_masks() -> Vector2i:
	return Vector2i(mask_upper, mask_lower)


func apply() -> void:
	_ensure_material()
	if _material == null:
		return
	_material.set_shader_parameter("mask_upper", mask_upper)
	_material.set_shader_parameter("mask_lower", mask_lower)


func show_number(number: int) -> void:
	stop_animation() # <--- Add this
	var masks := number_masks(number)
	set_masks(masks.x, masks.y)

func clear() -> void:
	stop_animation() # <--- Add this
	mask_upper = 0
	mask_lower = 0
	apply()



static func number_masks(number: int) -> Vector2i:
	if number < 1 or number > NUMBER_PATTERNS.size():
		push_error("DotMatrixDisplay: number must be 1-8, got %d" % number)
		return Vector2i(0, 0)
	return _masks_from_pattern(NUMBER_PATTERNS[number - 1])


static func _masks_from_pattern(pattern: String) -> Vector2i:
	return _masks_from_rows(pattern.split("\n"))


static func _masks_from_rows(rows: PackedStringArray) -> Vector2i:
	var upper := 0
	var lower := 0
	for row in range(mini(rows.size(), GRID_SIZE)):
		var line := rows[row]
		for col in range(mini(line.length(), GRID_SIZE)):
			if line[col] == ".":
				continue
			var index := row * GRID_SIZE + col + 1
			var bit := (index - 1) % 32
			if index <= 32:
				upper = (upper | (1 << bit)) & MASK_BITS
			else:
				lower = (lower | (1 << bit)) & MASK_BITS
	return Vector2i(upper, lower)


static func forward_gear_triangle(gear: int) -> Vector2i:
	var upper := 0
	var lower := 0
	var clamped_gear := clampi(gear, 0, GRID_SIZE)
	if clamped_gear <= 0:
		return Vector2i(0, 0)

	for row in range(GRID_SIZE):
		var row_from_bottom := GRID_SIZE - 1 - row
		if row_from_bottom >= clamped_gear:
			continue
		var width := clamped_gear - row_from_bottom
		for col_offset in range(width):
			var col := GRID_SIZE - 1 - col_offset
			var index := row * GRID_SIZE + col + 1
			if index <= 32:
				upper = (upper | (1 << ((index - 1) % 32))) & MASK_BITS
			else:
				lower = (lower | (1 << ((index - 1) % 32))) & MASK_BITS

	return Vector2i(upper, lower)


func _is_valid_index(index: int) -> bool:
	if index < 1 or index > GRID_SIZE * GRID_SIZE:
		push_error("DotMatrixDisplay: index must be 1-64, got %d" % index)
		return false
	return true
