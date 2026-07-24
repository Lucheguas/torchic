class_name MovementController
extends CharacterBody2D

## Core movement controller for the player character.
## Manages horizontal movement, variable-height jumping, gravity,
## coyote time, input buffering, stomp bounce, and landing events.
## External systems communicate via setter methods and outbound signals.

# --- Signals ---
signal landed(impact_velocity: float)
signal stomp_bounced()

# --- Exported Tuning Parameters ---

@export_group("Horizontal Movement")
@export var base_pixel_speed: float = 300.0  ## Pixels/sec at speed multiplier 1.0

@export_group("Jump")
@export var jump_velocity: float = -450.0  ## Initial upward impulse (negative = up)
@export var jump_cut_multiplier: float = 0.4  ## Applied when button released early
@export var min_jump_time: float = 0.08  ## Seconds of guaranteed jump force

@export_group("Gravity")
@export var gravity_up_multiplier: float = 1.0
@export var gravity_down_multiplier: float = 1.6
@export var terminal_velocity: float = 900.0

@export_group("Coyote Time")
@export var coyote_time_duration: float = 0.1  ## 100ms

@export_group("Input Buffer")
@export var input_buffer_duration: float = 0.12  ## 120ms

@export_group("Stomp Bounce")
@export var stomp_bounce_velocity: float = -350.0
@export var stomp_bounce_hold_velocity: float = -500.0

@export_group("Landing")
@export var landing_velocity_threshold: float = 200.0

# --- Internal State Variables ---

## Speed multiplier from player level (1.0 at level 1, up to 1.7 at level 15)
var _base_speed: float = 1.0

## Speed bonus from equipment (0.0 to 0.5)
var _speed_modifier: float = 0.0

## Jump height bonus from equipment (0.0 to 1.0, e.g. 0.05 = +5%)
var _jump_height_bonus: float = 0.0

## Whether double jump is enabled (from equipment)
var _double_jump_enabled: bool = false

## Whether the player has used their double jump this air cycle
var _has_double_jumped: bool = false

## Stomp bounce multiplier from equipment (1.0 to 2.0)
var _stomp_bounce_multiplier: float = 1.0

## Coyote time countdown timer
var _coyote_timer: float = 0.0

## Whether the player was on the floor last physics frame
var _was_on_floor_last_frame: bool = false

## Input buffer countdown timer for jump requests
var _jump_buffer_timer: float = 0.0

## Whether the player is currently in a jump
var _is_jumping: bool = false

## How long the jump button has been held this jump
var _jump_held_time: float = 0.0

## Whether a stomp bounce has been requested this frame
var _stomp_requested: bool = false

## Previous frame's vertical velocity (for landing detection)
var _previous_velocity_y: float = 0.0

# --- Animation State ---
var walk_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
const BOB_SPEED = 14.0
const BOB_AMOUNT = 3.0
const TILT_AMOUNT = 0.05
const SQUASH_AMOUNT = 0.03


func _ready() -> void:
	# Capture the sprite's scale from the scene so procedural animation
	# multiplies onto it instead of resetting it to 1.0.
	_base_sprite_scale = $Sprite2D.scale

# --- Public Setter Methods ---

## Sets the level-based speed multiplier. Clamped to [1.0, 1.7].
func set_base_speed(value: float) -> void:
	_base_speed = clampf(value, 1.0, 1.7)


## Sets the equipment speed bonus. Clamped to [0.0, 0.5].
func set_speed_modifier(value: float) -> void:
	_speed_modifier = clampf(value, 0.0, 0.5)


## Sets the jump height bonus percentage. Clamped to [0.0, 1.0].
func set_jump_height_bonus(percent: float) -> void:
	_jump_height_bonus = clampf(percent, 0.0, 1.0)


## Enables or disables double jump capability.
func set_double_jump_enabled(enabled: bool) -> void:
	_double_jump_enabled = enabled


## Sets the stomp bounce multiplier. Clamped to [1.0, 2.0].
func set_stomp_bounce_multiplier(mult: float) -> void:
	_stomp_bounce_multiplier = clampf(mult, 1.0, 2.0)


## Called by enemy collision system when a stomp hit occurs.
## Requests a bounce to be applied on the next physics frame.
func notify_stomp_hit() -> void:
	_stomp_requested = true

# --- Private Helper Methods ---

## Calculates the effective speed using current instance state.
func _calculate_effective_speed() -> float:
	return MovementController.calculate_effective_speed(base_pixel_speed, _base_speed, _speed_modifier)

# --- Static Utility Functions (Pure, for testing) ---

## Calculates the effective horizontal speed.
static func calculate_effective_speed(base_pixel_speed: float, base_speed: float, speed_modifier: float) -> float:
	return base_pixel_speed * (base_speed + speed_modifier)


## Applies gravity to the current vertical velocity, respecting terminal velocity.
static func apply_gravity(current_vy: float, gravity: float, multiplier: float, delta: float, terminal: float) -> float:
	return minf(current_vy + gravity * multiplier * delta, terminal)


## Applies jump cut to reduce ascending velocity.
static func apply_jump_cut(current_vy: float, cut_multiplier: float) -> float:
	return current_vy * cut_multiplier


## Interpolates base speed from player level (1-15).
static func interpolate_base_speed(level: int) -> float:
	var clamped_level := clampi(level, 1, 15)
	return 1.0 + (clamped_level - 1) * (0.7 / 14.0)

# --- Main Physics Loop ---

func _physics_process(delta: float) -> void:
	_handle_coyote_time(delta)
	_handle_input_buffer(delta)
	_handle_horizontal_movement()
	_handle_jump(delta)
	_handle_gravity(delta)
	_handle_stomp_bounce()

	# Store velocity before collision for landing detection
	_previous_velocity_y = velocity.y

	move_and_slide()

	_handle_landing()

	# Update frame tracking for next tick
	_was_on_floor_last_frame = is_on_floor()

	# Sprite flip and walk animation
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		$Sprite2D.flip_h = direction < 0.0
	_animate_walk(delta, direction)


func _animate_walk(delta: float, direction: float) -> void:
	if direction != 0.0 and is_on_floor():
		walk_time += delta * BOB_SPEED
		$Sprite2D.position.y = sin(walk_time) * BOB_AMOUNT
		$Sprite2D.rotation = sin(walk_time) * TILT_AMOUNT
		$Sprite2D.scale.x = _base_sprite_scale.x * (1.0 + cos(walk_time * 2.0) * SQUASH_AMOUNT)
		$Sprite2D.scale.y = _base_sprite_scale.y * (1.0 - cos(walk_time * 2.0) * SQUASH_AMOUNT)
	else:
		walk_time = 0.0
		$Sprite2D.position.y = lerp($Sprite2D.position.y, 0.0, 0.2)
		$Sprite2D.rotation = lerp($Sprite2D.rotation, 0.0, 0.2)
		$Sprite2D.scale.x = lerp($Sprite2D.scale.x, _base_sprite_scale.x, 0.2)
		$Sprite2D.scale.y = lerp($Sprite2D.scale.y, _base_sprite_scale.y, 0.2)

# --- Private Handler Methods ---

## Reads horizontal input and applies instant velocity (no acceleration/deceleration).
## Same behavior applies in both Ground_State and Air_State.
func _handle_horizontal_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * _calculate_effective_speed()
	else:
		velocity.x = 0.0


## Applies gravity with asymmetric multipliers (heavier on descent).
## Only applies when not on floor.
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		var multiplier: float
		if velocity.y < 0.0:
			multiplier = gravity_up_multiplier
		else:
			multiplier = gravity_down_multiplier
		velocity.y = MovementController.apply_gravity(velocity.y, gravity, multiplier, delta, terminal_velocity)


## Handles jump initiation, variable-height tracking, jump cut, and double jump.
## Implements variable-height jumping with minimum jump time guarantee.
func _handle_jump(delta: float) -> void:
	# Reset jumping state when landing
	if is_on_floor():
		_is_jumping = false

	# Can jump if on floor or within coyote time window
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	# Double jump in air: allowed once per air cycle when enabled (only when coyote time expired)
	var can_double_jump := not is_on_floor() and _double_jump_enabled and not _has_double_jumped and _coyote_timer <= 0.0

	# Jump initiation
	if Input.is_action_just_pressed("jump"):
		if can_jump:
			velocity.y = jump_velocity * (1.0 + _jump_height_bonus)
			_coyote_timer = 0.0  # Consume coyote time
			_is_jumping = true
			_jump_held_time = 0.0
		elif can_double_jump:
			velocity.y = jump_velocity * (1.0 + _jump_height_bonus)
			_has_double_jumped = true
			_is_jumping = true
			_jump_held_time = 0.0

	# Track held time while jumping and button is held
	if _is_jumping and Input.is_action_pressed("jump"):
		_jump_held_time += delta

	# Jump cut: button released early while still ascending
	if _is_jumping and not Input.is_action_pressed("jump"):
		if _jump_held_time > min_jump_time and velocity.y < 0:
			velocity.y = MovementController.apply_jump_cut(velocity.y, jump_cut_multiplier)
		_is_jumping = false


# --- Coyote Time Handler ---

## Manages coyote time countdown. Starts when walking off an edge (not jumping).
func _handle_coyote_time(delta: float) -> void:
	# Detect walk-off: was on floor last frame, now in air, and not jumping
	if _was_on_floor_last_frame and not is_on_floor() and not _is_jumping:
		_coyote_timer = coyote_time_duration

	# Countdown
	if _coyote_timer > 0.0:
		_coyote_timer -= delta


## Manages input buffer for jump requests made while airborne.
## Stores a jump press when the player is in the air and cannot jump,
## so it can be executed immediately upon landing.
func _handle_input_buffer(delta: float) -> void:
	# If jump pressed in air and can't jump right now, buffer it
	if Input.is_action_just_pressed("jump") and not is_on_floor() and _coyote_timer <= 0.0:
		# Only buffer if can't double jump either (or already used it)
		if not _double_jump_enabled or _has_double_jumped:
			_jump_buffer_timer = input_buffer_duration

	# Countdown the buffer timer each physics frame
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta


# --- Stomp Bounce Handler ---

## Handles stomp bounce when a stomp hit has been notified.
## Applies enhanced bounce if jump button is held.
func _handle_stomp_bounce() -> void:
	if not _stomp_requested:
		return

	# Only bounce in air
	if is_on_floor():
		_stomp_requested = false
		return

	# Apply bounce velocity (enhanced if jump held)
	if Input.is_action_pressed("jump"):
		velocity.y = stomp_bounce_hold_velocity * _stomp_bounce_multiplier
	else:
		velocity.y = stomp_bounce_velocity * _stomp_bounce_multiplier

	# Reset state and emit signal
	_stomp_requested = false
	_is_jumping = true
	_jump_held_time = 0.0
	stomp_bounced.emit()


# --- Landing Handler ---

## Detects air-to-ground transition and handles landing logic.
## Emits landed signal if impact velocity exceeds threshold.
## Resets double jump, consumes input buffer.
func _handle_landing() -> void:
	if is_on_floor() and not _was_on_floor_last_frame:
		# Emit landing signal if impact was significant
		if _previous_velocity_y > landing_velocity_threshold:
			landed.emit(_previous_velocity_y)

		# Reset double jump for next air cycle
		_has_double_jumped = false

		# Consume input buffer: execute buffered jump on landing
		if _jump_buffer_timer > 0.0:
			velocity.y = jump_velocity * (1.0 + _jump_height_bonus)
			_is_jumping = true
			_jump_held_time = 0.0
			_jump_buffer_timer = 0.0
