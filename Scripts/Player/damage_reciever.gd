extends CharacterBody3D
class_name DamageReciever

signal on_damage_taken(amount:int,stagger:int,sender)

func take_damage(amount:int,stagger,sender_pos)->void:
	on_damage_taken.emit(amount,stagger,sender_pos)
