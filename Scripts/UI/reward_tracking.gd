extends Control

class_name RewardTracking

var current_scans

@onready var reward_tiers_holder = $RewardTiers
@onready var num_scanned_value:Label = $NumScannedValue

var single_reward_tier = preload("res://Prefabs/UI/single_reward_tier.tscn")

func setup_reward_display(scannable:Scannable,scan_count:int):
	#Main case - Set everything up to be animated
	current_scans = scan_count
	num_scanned_value.text = str(current_scans)
	for requirement in scannable.scan_thresholds:
		var reward = scannable.scan_thresholds[requirement]
		var reward_display:SingleRewardTier = single_reward_tier.instantiate()
		reward_display.setup_single_reward(requirement,reward,current_scans)
		reward_tiers_holder.add_child(reward_display)
