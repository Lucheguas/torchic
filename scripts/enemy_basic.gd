class_name EnemyBasic
extends BaseEnemy
## Basic patrolling enemy (Tier 0.5) for the tutorial level.
## Walks left and right between two patrol bounds.
## Dies to a single stomp when unarmored; an armored one needs a melee hit first.

## Tint used only by the ColorRect fallback (when textures aren't assigned).
const ARMOR_COLOR := Color(0.62, 0.66, 0.72)

@export var patrol_speed: float = 80.0
@export var patrol_distance: float = 120.0  ## Distance from spawn to each side

# --- Texturas del enemigo (una por dirección, sin animación) ---
# Arrastra cada imagen a su ranura en el Inspector del nodo EnemyBasic.
# - Enemigo normal (has_armor = false): usa el set "normal".
# - Enemigo con armadura (has_armor = true): usa "armadura intacta" mientras la
#   tiene y "armadura rota" cuando se la rompen (no vuelve al set normal).
# Se auto-escalan por altura, así que da igual la resolución de origen.
@export_group("Texturas: normal")
## Mirando a la derecha.
@export var sprite_right: Texture2D
## Mirando a la izquierda.
@export var sprite_left: Texture2D

@export_group("Texturas: armadura intacta")
## Con armadura, a la derecha (armadura1).
@export var armor_intact_right: Texture2D
## Con armadura, a la izquierda (armadura1).
@export var armor_intact_left: Texture2D

@export_group("Texturas: armadura rota")
## Sin armadura tras recibir daño, a la derecha (armadura2).
@export var armor_broken_right: Texture2D
## Sin armadura tras recibir daño, a la izquierda (armadura2).
@export var armor_broken_left: Texture2D

@export_group("Visual")
## Altura en pantalla (px) a la que se dibuja el sprite, sin importar la
## resolución de la imagen. La escala se calcula sola a partir de esto.
@export var target_height: float = 36.0

var _spawn_position: Vector2
var _direction: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _base_color: Color
## Whether this instance started armored: an armored enemy keeps using its own
## art (intact/broken) instead of the plain normal sprite after the armor breaks.
var _had_armor: bool = false


func _ready() -> void:
	super._ready()  # wires $StompArea
	_spawn_position = global_position
	_base_color = $Sprite.color
	_had_armor = has_armor
	_update_visual()


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
		_update_visual()
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

	_update_visual()


# --- Visuals ---

## Shows the directional sprite for the current state. Armored enemies use their
## intact/broken art; normal enemies use the normal set. Falls back to the
## ColorRect when the needed textures aren't assigned.
func _update_visual() -> void:
	var right: Texture2D
	var left: Texture2D
	if _had_armor:
		if has_armor:
			right = armor_intact_right
			left = armor_intact_left
		else:
			right = armor_broken_right
			left = armor_broken_left
	else:
		right = sprite_right
		left = sprite_left

	if right == null or left == null:
		$Sprite.visible = true
		$Anim.visible = false
		$Sprite.color = ARMOR_COLOR if has_armor else _base_color
		return

	var tex: Texture2D = right if _direction >= 0.0 else left
	$Sprite.visible = false
	$Anim.visible = true
	$Anim.modulate = Color.WHITE
	$Anim.texture = tex
	# Auto-scale so any source resolution renders at target_height on screen.
	var h := tex.get_height()
	if h > 0:
		var s := target_height / float(h)
		$Anim.scale = Vector2(s, s)
