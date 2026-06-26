@tool
extends Node
class_name ScaleRuler

var _targetLengthFeet: float = 0.0

@export var targetLengthFeet: float:
	set = set_target_length_feet,
	get = get_target_length_feet

@onready var baseScaleObject:ScaleObject = $Base
@onready var copyContainer = $Copies

var numNeeded:int

func _ready() -> void:
	if not Engine.is_editor_hint(): queue_free()

func set_target_length_feet(value: float) -> void:
	if value == _targetLengthFeet:
		return  # No change, do nothing
	_targetLengthFeet = value
	_on_target_length_feet_changed(value)

func get_target_length_feet() -> float:
	return _targetLengthFeet

func _on_target_length_feet_changed(new_value: float) -> void:
	if not Engine.is_editor_hint(): return
	# This is your hook for any updates you want
	var targetLengthInches = targetLengthFeet*12.0
	var numberOfObjects = int(targetLengthInches/baseScaleObject.lengthInches)
	if(numberOfObjects==numNeeded):return
	numNeeded = numberOfObjects
	refresh_ruler()
	
func refresh_ruler():
	# Clear existing copies
	for thing in copyContainer.get_children():
		thing.queue_free()

	var numCopies = numNeeded - 1
	if numCopies <= 0:
		return  # nothing to add

	# Position to place the next copy: start at base's tail global position
	var positionToPlace = baseScaleObject.tail.global_position

	for i in range(numCopies):
		# Duplicate the baseScaleObject (deep copy)
		var copy = baseScaleObject.duplicate()
		copyContainer.add_child(copy)
		copy.owner = copyContainer.owner  # Set owner for editor scene saving

		# We want to position the copy so its head aligns with positionToPlace
		var head_global = copy.head.global_position
		var offset = positionToPlace - head_global

		# Move the whole copy by offset
		copy.global_position += offset

		# Update positionToPlace to the tail of this new copy for next iteration
		positionToPlace = copy.tail.global_position
