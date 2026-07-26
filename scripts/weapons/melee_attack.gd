class_name MeleeAttack
extends Area2D
## Player-owned Area2D hitbox that activates briefly when the weapon is triggered.
## Damage per hit and weapon identity come from the assigned MeleeWeapon resource.

@export var weapon: MeleeWeapon
@export var attack_duration: float = 0.15
## Distance in front of the player, in pixels. Together with the hitbox width it
## must out-reach the side contact-death range so the player can strike a
## ground enemy without dying on touch.
@export var attack_offset: float = 8.0

## Arc, in radians, that the blade visual sweeps across the swing. Purely
## cosmetic: the CollisionShape2D hitbox does not rotate.
const SWING_ARC: float = 1.4

var _attack_timer: float = 0.0
var _already_hit: Dictionary = {}  ## Enemies hit during the current swing
@onready var _blade: Node2D = $Blade


func _ready() -> void:
	monitoring = false
	visible = false
	_pivot_blade_at_bottom()
	body_entered.connect(_on_body_entered)


## Moves the blade art up so the node origin sits at its bottom edge. The swing
## then rotates around that base, reading like the weapon balances/pivots from
## the grip instead of spinning around its center.
func _pivot_blade_at_bottom() -> void:
	var sprite := _blade as Sprite2D
	if sprite != null and sprite.texture != null and sprite.centered:
		sprite.offset.y = -sprite.texture.get_height() * 0.5


## Activates the hitbox and visual in the given facing direction (+1 right, -1 left).
func trigger(facing: float) -> void:
	if _attack_timer > 0.0:
		return  # already swinging; wait until the current attack ends
	var sign_facing := 1.0 if facing >= 0.0 else -1.0
	position.x = attack_offset * sign_facing
	scale.x = sign_facing
	_attack_timer = attack_duration
	_already_hit.clear()
	monitoring = true
	visible = true


func _physics_process(delta: float) -> void:
	if _attack_timer <= 0.0:
		return
	_attack_timer -= delta
	# Sweep the blade from -half arc to +half arc across the swing for a slash
	# read. progress goes 0 -> 1 as the timer drains.
	var progress := 1.0 - clampf(_attack_timer / attack_duration, 0.0, 1.0)
	_blade.rotation = lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, progress)
	if _attack_timer <= 0.0:
		monitoring = false
		visible = false
		_blade.rotation = 0.0


func _on_body_entered(body: Node2D) -> void:
	if weapon == null:
		return
	if body is BaseEnemy and not (body as Node).is_queued_for_deletion():
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		var enemy := body as BaseEnemy
		enemy.take_damage(weapon.damage, BaseEnemy.DamageType.MELEE)
		# A surviving enemy (its armor just broke) is shoved in the swing
		# direction so the strike reads as landing and the player gets room for
		# the follow-up hit. A killed enemy is already gone; skip it.
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.apply_knockback(signf(scale.x))
