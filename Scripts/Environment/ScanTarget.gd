extends Node

class_name ScanTarget

enum SCAN_STATE{
	FRESH,
	STALE,
	COMPLETE
}

@export var scannable:Scannable
@export var fresh_material:ShaderMaterial
@export var stale_material:ShaderMaterial
@export var complete_material:ShaderMaterial

@onready var scan_marker = $MeshInstance3D

var scan_state:SCAN_STATE = SCAN_STATE.FRESH
var scanned = false

func _ready() -> void:
	add_to_group("ScanTarget")
	call_deferred("update_scan_display")
	if scannable:
		if scannable.scannable_type == Scannable.ScanType.SUPPORTER:
			$CompletionDisplay.visible = false


func set_scanned():
	scanned = true
	update_scan_display()

func update_scan_display():
	if not scannable or not scan_marker: 
		queue_free()
		return
	var state:SCAN_STATE = evaluate_scan_state()
	if state == SCAN_STATE.FRESH:
		scan_marker.material_override = fresh_material
	if state == SCAN_STATE.STALE:
		scan_marker.material_override = stale_material
	if state == SCAN_STATE.COMPLETE:
		scan_marker.material_override = complete_material

func evaluate_scan_state()->SCAN_STATE:
	var current_scans = 0
	var next_tier = get_next_scan_threshold(scannable.scan_thresholds, current_scans)
	update_counts(current_scans,next_tier)
	if scannable.scan_thresholds.is_empty(): return SCAN_STATE.COMPLETE
	if not scan_marker: return SCAN_STATE.COMPLETE
	var max_key = scannable.scan_thresholds.keys().max()
	if current_scans>= max_key:
		return SCAN_STATE.COMPLETE
	if scanned:
		return SCAN_STATE.STALE
	else:
		return SCAN_STATE.FRESH

func update_counts(current_scans,next_tier):
	pass

func get_next_scan_threshold(thresholds: Dictionary, number: float) -> Variant:
	var keys = thresholds.keys()
	keys.sort()
	for key in keys:
		if key > number:
			return key
	return 0

func get_scannable()->Scannable:
	return scannable
