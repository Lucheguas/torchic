class_name EnemyBasic
extends BaseEnemy
## Basic patrolling enemy (Tier 0.5) for the tutorial level.
## Walks left and right between two patrol bounds.
## Defeated by a single stomp via inherited BaseEnemy.take_stomp_damage.

@export var patrol_speed: float = 80.0
@export var patrol_distance: float = 120.0  ## Distance from spawn to each side

var _spawn_position: Vector2
var _direction: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	_spawn_position = global_position
	$StompArea.body_entered.connect(_on_stomp_area_body_entered)


func _on_stomp_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	# Position-based stomp check: the player must be above this enemy at the
	# moment of overlap. Using velocity.y > 0 is unreliable because
	# move_and_slide can zero the velocity on landing before Area2D signals
	# fire, causing the stomp to be missed inconsistently (Godot physics
	# resolution order depends on relative fall speed and geometry).
	if body.global_position.y < global_position.y:
		body.notify_stomp_hit()
		take_damage(1)  # inherited from BaseEnemy


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += _gravity * delta

	# Patrol movement
	velocity.x = _direction * patrol_speed
	move_and_slide()

	# Reverse direction at patrol bounds
	var distance_from_spawn := global_position.x - _spawn_position.x
	if distance_from_spawn > patrol_distance:
		_direction = -1.0
	elif distance_from_spawn < -patrol_distance:
		_direction = 1.0

	# Reverse on wall collision
	if is_on_wall():
		_direction *= -1.0
