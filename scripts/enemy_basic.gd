class_name EnemyBasic
extends BaseEnemy
## Basic patrolling enemy (Tier 0.5) for the tutorial level.
## Walks left and right between two patrol bounds.
## Dies to a single stomp when unarmored; an armored one needs a melee hit first.

## Body tint while armored, used only by the ColorRect fallback (before the walk
## textures are assigned). With textures, armor shows through its own frame set.
const ARMOR_COLOR := Color(0.62, 0.66, 0.72)

@export var patrol_speed: float = 80.0
@export var patrol_distance: float = 120.0  ## Distance from spawn to each side

# --- Texturas del enemigo ---
# Arrastra cada imagen a su ranura en el Inspector del nodo EnemyBasic.
# Mientras falten las 4 del set que toca (normal o con armadura), el enemigo usa
# el ColorRect de la escena con el comportamiento anterior (no se rompe nada).
# Un enemigo SIN armadura solo necesita el set normal; uno CON armadura necesita
# los dos sets (el normal es el que se muestra tras romperle la armadura).
@export_group("Texturas: caminar (normal)")
## Caminando a la derecha, pie derecho adelante.
@export var walk_right_a: Texture2D
## Caminando a la derecha, pie izquierdo adelante.
@export var walk_right_b: Texture2D
## Caminando a la izquierda, pie derecho adelante.
@export var walk_left_a: Texture2D
## Caminando a la izquierda, pie izquierdo adelante.
@export var walk_left_b: Texture2D

@export_group("Texturas: caminar (con armadura)")
## Con armadura, a la derecha, pie derecho adelante.
@export var armor_walk_right_a: Texture2D
## Con armadura, a la derecha, pie izquierdo adelante.
@export var armor_walk_right_b: Texture2D
## Con armadura, a la izquierda, pie derecho adelante.
@export var armor_walk_left_a: Texture2D
## Con armadura, a la izquierda, pie izquierdo adelante.
@export var armor_walk_left_b: Texture2D

@export_group("Animación")
## Segundos por cuadro del ciclo de dos pasos (más bajo = pasos más rápidos).
@export var walk_frame_time: float = 0.15

var _spawn_position: Vector2
var _direction: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _base_color: Color

## Two-foot walk cycle: which foot frame shows and the timer between swaps.
var _foot: int = 0
var _foot_timer: float = 0.0


func _ready() -> void:
	super._ready()  # wires $StompArea
	_spawn_position = global_position
	_base_color = $Sprite.color
	_update_visual(0.0)


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
		_update_visual(delta)
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

	_update_visual(delta)


# --- Visuals ---

## Drives the animated sprite when the current walk set (armored or normal) is
## assigned; otherwise keeps the ColorRect fallback with the armor tint.
func _update_visual(delta: float) -> void:
	if not _has_walk_frames(has_armor):
		$Sprite.visible = true
		$Anim.visible = false
		$Sprite.color = ARMOR_COLOR if has_armor else _base_color
		return

	$Sprite.visible = false
	$Anim.visible = true
	$Anim.modulate = Color.WHITE

	# Advance the two-foot cycle only while actually moving.
	if absf(velocity.x) > 5.0:
		_foot_timer += delta
		if _foot_timer >= walk_frame_time:
			_foot_timer -= walk_frame_time
			_foot = 1 - _foot
	else:
		_foot_timer = 0.0
		_foot = 0

	$Anim.texture = _current_frame()


## Picks the texture from the current set (armored/normal), direction and foot.
func _current_frame() -> Texture2D:
	if has_armor:
		if _direction >= 0.0:
			return armor_walk_right_a if _foot == 0 else armor_walk_right_b
		return armor_walk_left_a if _foot == 0 else armor_walk_left_b
	if _direction >= 0.0:
		return walk_right_a if _foot == 0 else walk_right_b
	return walk_left_a if _foot == 0 else walk_left_b


## True once the four textures of the requested set are all assigned.
func _has_walk_frames(armored: bool) -> bool:
	if armored:
		return (
			armor_walk_right_a != null and armor_walk_right_b != null
			and armor_walk_left_a != null and armor_walk_left_b != null
		)
	return (
		walk_right_a != null and walk_right_b != null
		and walk_left_a != null and walk_left_b != null
	)
