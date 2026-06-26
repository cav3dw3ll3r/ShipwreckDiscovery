extends RefCounted
class_name FishRaceResult

var race_id: String
var elapsed_sec: float
var checkpoint_count: int
var checkpoints_cleared: int
var race_controller: RaceController


func is_complete_run() -> bool:
	return checkpoints_cleared >= checkpoint_count and elapsed_sec > 0.0
