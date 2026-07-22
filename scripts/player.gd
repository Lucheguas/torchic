extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Gravedad del proyecto
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Animación de caminar (procedural)
var walk_time: float = 0.0
const BOB_SPEED = 14.0        # Velocidad de oscilación
const BOB_AMOUNT = 3.0        # Píxeles de desplazamiento vertical
const TILT_AMOUNT = 0.05      # Rotación en radianes al caminar
const SQUASH_AMOUNT = 0.03    # Squash & stretch al caminar

func _physics_process(delta: float) -> void:
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Salto (W, flecha arriba, o espacio)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimiento horizontal (A/D o flechas izquierda/derecha)
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Voltear el sprite según la dirección
	if direction != 0:
		$Sprite2D.flip_h = direction < 0

	move_and_slide()

	# Animación procedural
	_animate_walk(delta, direction)

func _animate_walk(delta: float, direction: float) -> void:
	if direction != 0 and is_on_floor():
		# Caminar: aplicar bobbing, tilt y squash
		walk_time += delta * BOB_SPEED
		$Sprite2D.position.y = sin(walk_time) * BOB_AMOUNT
		$Sprite2D.rotation = sin(walk_time) * TILT_AMOUNT
		$Sprite2D.scale.x = 1.0 + cos(walk_time * 2.0) * SQUASH_AMOUNT
		$Sprite2D.scale.y = 1.0 - cos(walk_time * 2.0) * SQUASH_AMOUNT
	else:
		# Quieto o en el aire: volver al estado normal suavemente
		walk_time = 0.0
		$Sprite2D.position.y = lerp($Sprite2D.position.y, 0.0, 0.2)
		$Sprite2D.rotation = lerp($Sprite2D.rotation, 0.0, 0.2)
		$Sprite2D.scale.x = lerp($Sprite2D.scale.x, 1.0, 0.2)
		$Sprite2D.scale.y = lerp($Sprite2D.scale.y, 1.0, 0.2)
