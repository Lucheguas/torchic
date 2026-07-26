class_name EnemyBasic
extends BaseEnemy
## Basic patrolling enemy (Tier 0.5) for the tutorial level.
## Walks left and right between two patrol bounds.
## Dies to a single stomp when unarmored; an armored one needs a melee hit first.

## Body tint while armored. The unarmored tint comes from the scene, so the
## .tscn stays the source of truth for the enemy's normal look.
const ARMOR_COLOR := Color(0.62, 0.66, 0.72)

@export var patrol_speed: float = 80.0
@export var patrol_distance: float = 120.0  ## Distance from spawn to each side

var _spawn_position: Vector2
var _direction: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _base_color: Color


func _ready() -> void:
	_spawn_position = global_position
	_base_color = $Sprite.color
	if has_armor:
		$Sprite.color = ARMOR_COLOR
	armor_broken.connect(_on_armor_broken)
	$StompArea.body_entered.connect(_on_stomp_area_body_entered)


func _on_armor_broken() -> void:
	$Sprite.color = _base_color


func _on_stomp_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	# Position-based stomp check: the player must be above this enemy at the
	# moment of overlap. Using velocity.y > 0 is unreliable because
	# move_and_slide can zero the velocity on landing before Area2D signals
	# fire, causing the stomp to be missed inconsistently (Godot physics
	# resolution order depends on relative fall speed and geometry).
	if body.global_position.y < global_position.y:
		# The bounce is unconditional: armor stops the damage, not the stomp.
		body.notify_stomp_hit()
		take_damage(1, DamageType.STOMP)  # inherited from BaseEnemy


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += _gravity * delta

	# Knockback overrides patrol until it expires; skip the turn-around logic so
	# a shoved enemy keeps sliding instead of instantly reversing on the push.
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_velocity_x
		move_and_slide()
		_check_player_contact()
		return

	# Patrol movement
	velocity.x = _direction * patrol_speed
	move_and_slide()
	_check_player_contact()

	# Reverse direction at patrol bounds
	var distance_from_spawn := global_position.x - _spawn_position.x
	if distance_from_spawn > patrol_distance:
		_direction = -1.0
	elif distance_from_spawn < -patrol_distance:
		_direction = 1.0

	# Reverse on wall collision
	if is_on_wall():
		_direction *= -1.0


## Kills the player when THIS enemy walks into them from the side or below,
## which the player's own slide-collision check misses while standing still.
## Near-vertical contacts are stomps (the player landed on top) and are left to
## StompArea, so only side/below contacts are lethal here.
func _check_player_contact() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is CharacterBody2D and (collider as CharacterBody2D).is_in_group("player"):
			if EnemyBasic.is_side_contact(collision.get_normal().y):
				LevelManager.handle_player_death()
				return


## True when a body-contact normal means a side/bottom hit (lethal to the
## player). Near-vertical normals mean the player is on top (a stomp).
static func is_side_contact(normal_y: float) -> bool:
	return absf(normal_y) < 0.7
