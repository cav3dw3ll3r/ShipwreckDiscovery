extends Node

class_name SingleRewardTier

var complete_icon:Texture = preload("res://Resources/Stylesheets/UI_Components/Component01/CheckboxCyan_On.png")
var incomplete_icon:Texture = preload("res://Resources/Stylesheets/UI_Components/Component01/CheckboxCyan_Off.png")

func setup_single_reward(requirement:int, reward:int, current_scans:int):
	$RewardRequirement.text = str(requirement)
	$RewardAmount.text = str(reward)
	if(current_scans>=requirement):
		$IsComplete.texture = complete_icon
	else:
		$IsComplete.texture = incomplete_icon
