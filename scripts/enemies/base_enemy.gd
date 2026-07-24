class_name BaseEnemy
extends CharacterBody2D
## Base class for enemies with hit points and stomp-defeat behavior.
## Subclasses inherit hp, take_stomp_damage, and death.

@export var hp: int = 1


## Subtracts amount from hp and frees the node if hp drops to zero or below.
## Amount defaults to 1 so subclasses can call take_stomp_damage() with no args
## for the common single-hit stomp.
func take_stomp_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
