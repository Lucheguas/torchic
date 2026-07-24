class_name BaseEnemy
extends CharacterBody2D
## Base class for enemies with hit points and stomp-defeat behavior.
## Subclasses inherit hp, take_stomp_damage, and death.

@export var hp: int = 1


## Subtracts amount from hp and frees the node if hp drops to zero or below.
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
