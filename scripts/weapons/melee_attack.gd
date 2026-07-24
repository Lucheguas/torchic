class_name MeleeAttack
extends Area2D
## Player-owned Area2D hitbox that activates briefly when the weapon is triggered.
## Damage per hit and weapon identity come from the assigned MeleeWeapon resource.

@export var weapon: MeleeWeapon
@export var attack_duration: float = 0.15
@export var attack_offset: float = 22.0  ## Distance in front of the player, in pixels

var _attack_timer: float = 0.0
var _already_hit: Dictionary = {}  ## Enemies hit during the current swing


func _ready() -> void:
	monitoring = false
	visible = false
	body_entered.connect(_on_body_entered)


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
	if _attack_timer <= 0.0:
		monitoring = false
		visible = false


func _on_body_entered(body: Node2D) -> void:
	if weapon == null:
		return
	if body is BaseEnemy and not (body as Node).is_queued_for_deletion():
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		(body as BaseEnemy).take_damage(weapon.damage)
