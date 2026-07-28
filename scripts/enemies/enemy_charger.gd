class_name EnemyCharger
extends BaseEnemy
## Charging enemy: patrols like a basic enemy until it SEES the player (in range,
## roughly level, with clear line of sight). Then it commits:
## - Player at close range  -> short telegraph + a quick lethal lunge (golpe).
## - Player farther away     -> 0.5s telegraph, then a straight charge that locks
##   its direction and does NOT home. It runs until it hits a wall or runs off a
##   ledge into the void.
## Contact is lethal in every state (inherited from BaseEnemy); the charge just
## makes the enemy cover ground fast. Counterplay: dodge the telegraph, stomp it,
## or bait it off a ledge.

enum State { PATROL, WINDUP, CHARGE, ATTACK_WINDUP, ATTACK_LUNGE, RECOVER, FALLING }

## Result of sizing up the player's horizontal distance.
enum RangeBand { NONE, MELEE, CHARGE }

@export_group("Patrol")
@export var patrol_speed: float = 80.0
@export var patrol_distance: float = 120.0  ## Distance from spawn to each side

@export_group("Detection")
@export var detection_range: float = 160.0  ## Horizontal sight distance
@export var melee_range: float = 40.0  ## Closer than this -> golpe instead of charge
@export var y_detection_tolerance: float = 24.0  ## Max height difference to "see" the player

@export_group("Charge")
@export var windup_duration: float = 0.5  ## Telegraph before charging
@export var charge_speed: float = 220.0
## Charge stops after covering this many blocks even if nothing gets in the way,
## so it commits to a meaningful distance without sprinting across the level.
@export var charge_max_blocks: float = 5.0
@export var charge_block_size: float = 64.0  ## Pixels per block (matches the tileset)
@export var recover_duration: float = 0.7  ## Stunned pause after a charge ends

@export_group("Golpe (close range)")
@export var attack_windup: float = 0.3  ## Telegraph before the lunge
@export var attack_lunge_speed: float = 233.0  ## ~28 px over 0.12 s
@export var attack_lunge_duration: float = 0.12

@export_group("Fall")
@export var fall_kill_offset: float = 400.0  ## Removed once it drops this far below spawn

# --- Texturas del enemigo (2 cuadros por lado) ---
# Arrastra cada imagen a su ranura en el Inspector del nodo EnemyCharger.
# Los mismos dos cuadros por lado se usan para caminar y para embestir: caminando
# se alternan a ritmo normal; embistiendo se alternan más rápido para que parezca
# que corre. Mientras falte cualquiera de los 4, el enemigo usa el ColorRect de la
# escena (no se rompe nada).
@export_group("Texturas: derecha")
## Mirando a la derecha, cuadro 1 (CHARGERDERECHA1).
@export var sprite_right_1: Texture2D
## Mirando a la derecha, cuadro 2 (CHARGERDERECHA2).
@export var sprite_right_2: Texture2D

@export_group("Texturas: izquierda")
## Mirando a la izquierda, cuadro 1 (CHARGERIZQUIERDA1).
@export var sprite_left_1: Texture2D
## Mirando a la izquierda, cuadro 2 (CHARGERIZQUIERDA2).
@export var sprite_left_2: Texture2D

@export_group("Animación")
## Segundos por cuadro caminando (ritmo normal).
@export var walk_frame_time: float = 0.18
## Segundos por cuadro embistiendo (más bajo = alternancia rápida, "corre").
@export var charge_frame_time: float = 0.06

## Body tint while armored (matches EnemyBasic so armor reads the same).
const ARMOR_COLOR := Color(0.62, 0.66, 0.72)
## Warning flash while telegraphing an attack.
const WINDUP_COLOR := Color(1.0, 0.85, 0.2)
## Vertical offset used for the line-of-sight ray so it aims at torso height
## instead of the feet, where it would clip ledges.
const SIGHT_EYE_OFFSET := Vector2(0, -16)

var _state: State = State.PATROL
var _spawn_position: Vector2
var _direction: float = 1.0  ## Patrol direction (+1 right, -1 left)
var _charge_dir: float = 1.0  ## Locked charge/lunge direction
var _charge_start_x: float = 0.0  ## X where the current charge began (for the block cap)
var _timer: float = 0.0  ## Countdown for the current timed state
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _base_color: Color

## Direction the body is drawn facing (+1 right, -1 left). Updated by movement.
var _facing: float = 1.0
## Two-foot walk cycle: which foot frame shows and the timer between swaps.
var _foot: int = 0
var _foot_timer: float = 0.0


func _ready() -> void:
	super._ready()  # wires $StompArea
	_spawn_position = global_position
	_base_color = $Sprite.color
	_update_visual(0.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	# Knockback overrides everything while it lasts (armor just broke, etc.).
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_velocity_x
		move_and_slide()
		_check_player_contact()
		return

	match _state:
		State.PATROL:
			_tick_patrol()
		State.WINDUP:
			_tick_windup(delta)
		State.CHARGE:
			velocity.x = _charge_dir * charge_speed
		State.ATTACK_WINDUP:
			_tick_attack_windup(delta)
		State.ATTACK_LUNGE:
			_tick_attack_lunge(delta)
		State.RECOVER:
			_tick_recover(delta)
		State.FALLING:
			velocity.x = _charge_dir * charge_speed * 0.5

	move_and_slide()
	_check_player_contact()
	_post_move_transitions()
	_update_visual(delta)


# --- Per-state pre-move logic ---

func _tick_patrol() -> void:
	velocity.x = _direction * patrol_speed
	_facing = _direction
	# Reverse at patrol bounds so it stays on its platform while idle.
	var distance_from_spawn := global_position.x - _spawn_position.x
	if distance_from_spawn > patrol_distance:
		_direction = -1.0
	elif distance_from_spawn < -patrol_distance:
		_direction = 1.0

	var player := _find_player()
	if player != null and _can_see(player):
		_facing = _face_toward(player)
		match _classify_range(player):
			RangeBand.MELEE:
				_enter_attack(player)
			RangeBand.CHARGE:
				_enter_windup()


func _tick_windup(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		# Lock the charge direction toward the player NOW, then run straight.
		# The 0.5s telegraph plus the straight (non-homing) charge is the
		# player's dodge window.
		var player := _find_player()
		if player != null:
			_charge_dir = signf(player.global_position.x - global_position.x)
			if _charge_dir == 0.0:
				_charge_dir = _direction
		else:
			_charge_dir = _direction
		_charge_start_x = global_position.x
		_facing = _charge_dir
		_state = State.CHARGE


func _tick_attack_windup(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		var player := _find_player()
		if player != null:
			_charge_dir = signf(player.global_position.x - global_position.x)
			if _charge_dir == 0.0:
				_charge_dir = _direction
		else:
			_charge_dir = _direction
		_timer = attack_lunge_duration
		_facing = _charge_dir
		_state = State.ATTACK_LUNGE


func _tick_attack_lunge(delta: float) -> void:
	velocity.x = _charge_dir * attack_lunge_speed
	_timer -= delta
	if _timer <= 0.0:
		_enter_recover()


func _tick_recover(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_resume_from_recover()


# --- Post-move transitions (use is_on_wall/is_on_floor from this frame) ---

func _post_move_transitions() -> void:
	match _state:
		State.PATROL:
			# Turn around on wall so patrol never grinds into geometry.
			if is_on_wall():
				_direction *= -1.0
		State.CHARGE:
			if is_on_wall():
				_enter_recover()
			elif not is_on_floor():
				# Ran off the platform: commit to the fall and drop out.
				_state = State.FALLING
			elif absf(global_position.x - _charge_start_x) >= charge_max_blocks * charge_block_size:
				# Covered its committed distance without hitting anything.
				_enter_recover()
		State.FALLING:
			if global_position.y > _spawn_position.y + fall_kill_offset:
				queue_free()


# --- State entry helpers ---

func _enter_windup() -> void:
	velocity.x = 0.0
	_timer = windup_duration
	_state = State.WINDUP


func _enter_attack(player: Node2D) -> void:
	velocity.x = 0.0
	_timer = attack_windup
	_facing = _face_toward(player)
	_state = State.ATTACK_WINDUP


func _enter_recover() -> void:
	velocity.x = 0.0
	_timer = recover_duration
	_state = State.RECOVER


## After recovering, look again: charge/golpe if the player is still visible,
## otherwise resume patrol walking AWAY from whatever we just hit.
func _resume_from_recover() -> void:
	var player := _find_player()
	if player != null and _can_see(player):
		match _classify_range(player):
			RangeBand.MELEE:
				_enter_attack(player)
				return
			RangeBand.CHARGE:
				_facing = _face_toward(player)
				_enter_windup()
				return
	_direction = -_charge_dir if _charge_dir != 0.0 else _direction
	_state = State.PATROL


# --- Detection ---

func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


## Sizes up the player's horizontal distance into a reaction band.
func _classify_range(player: Node2D) -> RangeBand:
	var dist := absf(player.global_position.x - global_position.x)
	return EnemyCharger.classify_range(dist, melee_range, detection_range)


## Pure range classification (unit-testable). NONE beyond detection_range.
static func classify_range(dist: float, melee: float, detection: float) -> RangeBand:
	if dist > detection:
		return RangeBand.NONE
	if dist <= melee:
		return RangeBand.MELEE
	return RangeBand.CHARGE


## True when the player is within range, roughly level, and nothing blocks the
## sight line. A wall between us cancels the charge ("si está cubierto no embiste").
func _can_see(player: Node2D) -> bool:
	var to_player := player.global_position - global_position
	if absf(to_player.x) > detection_range:
		return false
	if absf(to_player.y) > y_detection_tolerance:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position + SIGHT_EYE_OFFSET,
		player.global_position + SIGHT_EYE_OFFSET
	)
	# Exclude self and player so only world geometry (walls/ground) can block.
	var exclusions: Array[RID] = [get_rid()]
	if player is CollisionObject2D:
		exclusions.append((player as CollisionObject2D).get_rid())
	query.exclude = exclusions
	var hit := space.intersect_ray(query)
	return hit.is_empty()


# --- Visuals ---

## Facing sign (+1/-1) toward a target, falling back to the current facing when
## perfectly aligned so it never snaps to a neutral 0.
func _face_toward(target: Node2D) -> float:
	var s := signf(target.global_position.x - global_position.x)
	return s if s != 0.0 else _facing


## Drives the animated sprite when the 8 textures are assigned; otherwise keeps
## the ColorRect fallback. Also applies the readability tint (armor grey while
## armored, warning flash while telegraphing) to whichever visual is active.
func _update_visual(delta: float) -> void:
	var tint := _current_tint()

	if not _has_frames():
		# Fallback: colored box. Neutral tint is the scene's base color.
		$Sprite.visible = true
		$Anim.visible = false
		$Sprite.color = tint if tint != Color.WHITE else _base_color
		return

	$Sprite.visible = false
	$Anim.visible = true
	$Anim.modulate = tint

	# Same two frames per side for walk and charge; alternate faster while
	# charging/lunging so it reads as running instead of walking.
	var charging := _state == State.CHARGE or _state == State.ATTACK_LUNGE
	var frame_time := charge_frame_time if charging else walk_frame_time

	# Advance the cycle only while actually moving; plant on frame 0 when
	# standing (windup/recover).
	if absf(velocity.x) > 5.0:
		_foot_timer += delta
		if _foot_timer >= frame_time:
			_foot_timer -= frame_time
			_foot = 1 - _foot
	else:
		_foot_timer = 0.0
		_foot = 0

	$Anim.texture = _current_frame()


## Picks the texture for this frame from the current side and cycle frame.
func _current_frame() -> Texture2D:
	if _facing >= 0.0:
		return sprite_right_1 if _foot == 0 else sprite_right_2
	return sprite_left_1 if _foot == 0 else sprite_left_2


## White = no tint. Grey while armored, warning color while telegraphing an
## attack (windup); telegraph wins over armor so the tell is always readable.
func _current_tint() -> Color:
	if _state == State.WINDUP or _state == State.ATTACK_WINDUP:
		return WINDUP_COLOR
	if has_armor:
		return ARMOR_COLOR
	return Color.WHITE


## True once the four directional textures (2 per side) are assigned.
func _has_frames() -> bool:
	return (
		sprite_right_1 != null and sprite_right_2 != null
		and sprite_left_1 != null and sprite_left_2 != null
	)
