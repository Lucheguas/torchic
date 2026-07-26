class_name BaseEnemy
extends CharacterBody2D
## Base class for enemies with hit points, armor and death handling.
## Subclasses inherit hp, has_armor, take_damage and the armor_broken signal.

## Emitted when a melee hit strips this enemy's armor. Subclasses react to update
## their visuals; the base class owns no sprite of its own.
signal armor_broken()

## How the damage reached the enemy. Armor only yields to MELEE.
enum DamageType { STOMP, MELEE }

@export var hp: int = 1
@export var has_armor: bool = false

const KNOCKBACK_SPEED: float = 200.0
const KNOCKBACK_DURATION: float = 0.12

## Horizontal knockback state. A moving subclass reads these in its physics loop
## and lets the knockback override patrol while the timer is positive.
var _knockback_velocity_x: float = 0.0
var _knockback_timer: float = 0.0


## Shoves the enemy horizontally for a short time. direction: +1 right, -1 left.
func apply_knockback(direction: float) -> void:
	_knockback_velocity_x = signf(direction) * KNOCKBACK_SPEED
	_knockback_timer = KNOCKBACK_DURATION


## Applies damage following the combat matrix: armor absorbs stomps entirely and
## breaks on melee. An unarmored enemy loses hp and dies at hp <= 0.
## The stomp bounce is the player's business and happens regardless of armor.
func take_damage(amount: int, type: DamageType) -> void:
	if has_armor:
		if type == DamageType.MELEE:
			_break_armor()
		return

	hp -= amount
	if hp <= 0:
		queue_free()


func _break_armor() -> void:
	has_armor = false
	armor_broken.emit()
