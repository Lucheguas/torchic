class_name BaseEnemy
extends CharacterBody2D
## Base class for enemies with hit points, armor and death handling.
## Subclasses inherit hp, has_armor, take_damage and the armor_broken signal.

## Emitted when a melee hit strips this enemy's armor. Subclasses react to update
## their visuals; the base class owns no sprite of its own.
signal armor_broken()

## How the damage reached the enemy. Armor only yields to MELEE.
enum DamageType { STOMP, MELEE }

@export var hp: float = 3.0
@export var has_armor: bool = false

const KNOCKBACK_SPEED: float = 200.0
const KNOCKBACK_DURATION: float = 0.12

## Horizontal knockback state. A moving subclass reads these in its physics loop
## and lets the knockback override patrol while the timer is positive.
var _knockback_velocity_x: float = 0.0
var _knockback_timer: float = 0.0


## Wires the stomp area if the enemy scene has one. Not every enemy is
## stompable, so the child is optional. Subclasses that override _ready must
## call super._ready().
func _ready() -> void:
	if has_node("StompArea"):
		$StompArea.body_entered.connect(_on_stomp_area_body_entered)


## Shoves the enemy horizontally for a short time. direction: +1 right, -1 left.
func apply_knockback(direction: float) -> void:
	_knockback_velocity_x = signf(direction) * KNOCKBACK_SPEED
	_knockback_timer = KNOCKBACK_DURATION


## Applies damage following the combat matrix: armor absorbs stomps entirely and
## breaks on melee. Once unarmored, a melee hit chips hp by the weapon's damage
## while a stomp is a one-hit kill (a design decision: an unarmored enemy always
## dies to a single stomp, no matter its hp). The bounce itself is the player's
## business and happens regardless of armor.
func take_damage(amount: float, type: DamageType) -> void:
	if has_armor:
		if type == DamageType.MELEE:
			_break_armor()
		return

	if type == DamageType.STOMP:
		hp = 0.0
	else:
		hp -= amount
	if hp <= 0.0:
		queue_free()


func _break_armor() -> void:
	has_armor = false
	armor_broken.emit()


## Position-based stomp check shared by every stompable enemy: the player must
## be above this enemy at the moment of overlap. Using velocity.y > 0 is
## unreliable because move_and_slide can zero the velocity on landing before the
## Area2D signal fires. The bounce is unconditional: armor stops the damage, not
## the stomp.
func _on_stomp_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	if body.global_position.y < global_position.y:
		body.notify_stomp_hit()
		take_damage(1, DamageType.STOMP)


## Kills the player when THIS enemy walks into them from the side or below,
## which the player's own slide-collision check misses while standing still.
## Near-vertical contacts are stomps (the player landed on top) and are left to
## StompArea, so only side/below contacts are lethal here. Subclasses call this
## right after their move_and_slide().
func _check_player_contact() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is CharacterBody2D and (collider as CharacterBody2D).is_in_group("player"):
			if BaseEnemy.is_side_contact(collision.get_normal().y):
				LevelManager.handle_player_death()
				return


## True when a body-contact normal means a side/bottom hit (lethal to the
## player). Near-vertical normals mean the player is on top (a stomp).
static func is_side_contact(normal_y: float) -> bool:
	return absf(normal_y) < 0.7
