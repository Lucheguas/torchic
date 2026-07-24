# Design Document

## Overview

This refactor introduces two new base classes (`PlayerTrigger`, `BaseEnemy`), one new composition object (`ModifierStack`), and one delegation change (`KillZone` → `LevelManager`). No `.tscn` files are edited. All existing `class_name` identifiers, exported fields, and signals are preserved so `floor_1.tscn` continues to load and run unchanged.

Design goals:
- Consolidate duplicated player-detection code behind `PlayerTrigger`.
- Consolidate duplicated stomp-defeat code behind `BaseEnemy`.
- Extract modifier state from `MovementController` into a testable `ModifierStack` object.
- Route hazard-triggered respawn through `LevelManager` so KillZone shares the checkpoint flow with other death paths.
- Cover all new classes with GdUnit4 unit tests.

Priority order for implementation follows the requirements document: `BaseEnemy` and `ModifierStack` (HIGH), `PlayerTrigger` (MEDIUM), `KillZone` delegation (LOW).

## Architecture

Two orthogonal changes to the type hierarchy:

```
CharacterBody2D
└── BaseEnemy          (new, scripts/enemies/base_enemy.gd)
    └── EnemyBasic     (updated, scripts/enemy_basic.gd)

Area2D
└── PlayerTrigger      (new, scripts/triggers/player_trigger.gd)
    ├── TransitionTrigger      (updated, scripts/level_system/transition_trigger.gd)
    ├── SublevelExitTrigger    (updated, scripts/level_system/sublevel_exit_trigger.gd)
    └── CheckpointMarker       (updated, scripts/level_system/checkpoint_marker.gd)

Area2D
└── KillZone           (updated, scripts/kill_zone.gd — delegates to LevelManager)

RefCounted
└── ModifierStack      (new, scripts/modifier_stack.gd — owned by MovementController)
```

Compositional relationship for the player controller:

```
MovementController (CharacterBody2D)
  └── _modifiers: ModifierStack   (composition, owned reference)
```

All new files live alongside existing scripts. No autoload changes are required.

### File Layout

| File | Status | Purpose |
|---|---|---|
| `scripts/enemies/base_enemy.gd` | new | `BaseEnemy` class, HP + damage + death |
| `scripts/enemy_basic.gd` | updated | now `extends BaseEnemy`, delegates stomp defeat |
| `scripts/triggers/player_trigger.gd` | new | `PlayerTrigger` base class for one-shot player triggers |
| `scripts/level_system/transition_trigger.gd` | updated | `extends PlayerTrigger`, overrides `_on_player_entered` |
| `scripts/level_system/sublevel_exit_trigger.gd` | updated | `extends PlayerTrigger`, overrides `_on_player_entered` |
| `scripts/level_system/checkpoint_marker.gd` | updated | `extends PlayerTrigger`, overrides `_on_player_entered` |
| `scripts/kill_zone.gd` | updated | delegates respawn to `LevelManager.handle_player_death()` |
| `scripts/modifier_stack.gd` | new | `ModifierStack` RefCounted with clamped setters |
| `scripts/movement_controller.gd` | updated | owns a `ModifierStack`, forwards setter calls |
| `tests/base_enemy_test.gd` | new | GdUnit4 tests |
| `tests/modifier_stack_test.gd` | new | GdUnit4 tests |
| `tests/player_trigger_test.gd` | new | GdUnit4 tests |
| `tests/kill_zone_test.gd` | new | GdUnit4 tests |

## Components and Interfaces

### PlayerTrigger (new base class)

A one-shot player-detecting `Area2D`. Handles the boilerplate that `TransitionTrigger`, `SublevelExitTrigger`, and `CheckpointMarker` currently duplicate: connecting `body_entered`, filtering for `CharacterBody2D` in the `player` group, and disconnecting after the first fire.

```gdscript
class_name PlayerTrigger
extends Area2D
## Base class for Area2D triggers that fire once when the player enters.
## Subclasses override _on_player_entered(body) to define the effect.

var _fired: bool = false


func _ready() -> void:
    if not body_entered.is_connected(_handle_body_entered):
        body_entered.connect(_handle_body_entered)


## Virtual method. Subclasses override this to define the trigger effect.
## Called exactly once, on the first CharacterBody2D in the "player" group
## to enter the trigger area.
func _on_player_entered(_body: Node2D) -> void:
    pass


func _handle_body_entered(body: Node2D) -> void:
    if _fired:
        return
    if not (body is CharacterBody2D and body.is_in_group("player")):
        return
    _fired = true
    _on_player_entered(body)
    if body_entered.is_connected(_handle_body_entered):
        body_entered.disconnect(_handle_body_entered)
```

Key contract points:
- The virtual `_on_player_entered(body)` is the sole extension point for subclasses.
- The one-shot latch (`_fired`) plus signal disconnect guarantees the override runs at most once, even if the disconnect is deferred.
- Non-player bodies are ignored without consuming the one-shot.

### TransitionTrigger (updated)

Refactored to `extends PlayerTrigger`. All exported fields and the `triggered` signal are preserved verbatim so `floor_1.tscn` needs no edits.

```gdscript
class_name TransitionTrigger
extends PlayerTrigger

signal triggered(trigger: TransitionTrigger)

enum TargetType { SUBLEVEL, ENTRE_NIVEL, NEXT_FLOOR }

@export var target_type: TargetType = TargetType.SUBLEVEL
@export var sublevel_config: SubLevelConfig = null
@export var transition_visual: TransitionAnimator.TransitionType = TransitionAnimator.TransitionType.DOOR


func _on_player_entered(_body: Node2D) -> void:
    triggered.emit(self)
```

Removed: the local `_ready` override and local `_on_body_entered` handler (now inherited from `PlayerTrigger`).

### SublevelExitTrigger (updated)

```gdscript
class_name SublevelExitTrigger
extends PlayerTrigger


func _on_player_entered(_body: Node2D) -> void:
    LevelManager.complete_sublevel()
```

### CheckpointMarker (updated)

The marker keeps its own `activate()` method (which manages `is_active`, sprite modulation, animation, and the `marker_activated` signal). The override just calls `activate()`:

```gdscript
class_name CheckpointMarker
extends PlayerTrigger

signal marker_activated()

var is_active: bool = false

@onready var flag_sprite: Sprite2D = $CheckpointFlag
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const INACTIVE_COLOR := Color(0.5, 0.5, 0.5, 1.0)
const ACTIVE_COLOR := Color(0.2, 0.9, 0.2, 1.0)


func _ready() -> void:
    super._ready()  # connect PlayerTrigger's body_entered handler
    flag_sprite.modulate = INACTIVE_COLOR


func _on_player_entered(_body: Node2D) -> void:
    if not is_active:
        activate()


func activate() -> void:
    if is_active:
        return
    is_active = true
    flag_sprite.modulate = ACTIVE_COLOR
    animation_player.play("wave")
    marker_activated.emit()
```

The `super._ready()` call is required because `CheckpointMarker` needs its own `_ready` for sprite setup. `PlayerTrigger._ready` is idempotent (guarded by `is_connected`).

### BaseEnemy (new base class)

Owns HP and death for stompable enemies.

```gdscript
class_name BaseEnemy
extends CharacterBody2D
## Base class for enemies with hit points and stomp-defeat behavior.
## Subclasses inherit hp, take_stomp_damage, and death.

@export var hp: int = 1


## Subtracts amount from hp and frees the node if hp drops to zero or below.
## Amount defaults to 1 so subclasses can call take_stomp_damage() with no args
## for the common single-hit stomp.
func take_stomp_damage(amount: int = 1) -> void:
    hp -= amount
    if hp <= 0:
        queue_free()
```

Notes:
- `hp` is exported so level designers can set higher HP directly in the scene inspector for tougher enemies later.
- Subclasses call `take_stomp_damage(1)` from their existing stomp callbacks. No signal fan-out is required for the initial refactor; a future extension could emit `damaged` / `defeated` signals.

### EnemyBasic (updated)

`extends BaseEnemy` (was `CharacterBody2D`). Removes its own `take_stomp_damage()` method; inherits the parent's version.

```gdscript
class_name EnemyBasic
extends BaseEnemy
## Basic patrolling enemy. Walks between two patrol bounds, gravity applied.
## Defeated by a single stomp via inherited BaseEnemy.take_stomp_damage.

@export var patrol_speed: float = 80.0
@export var patrol_distance: float = 120.0

var _spawn_position: Vector2
var _direction: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
    _spawn_position = global_position
    $StompArea.body_entered.connect(_on_stomp_area_body_entered)


func _on_stomp_area_body_entered(body: Node2D) -> void:
    if body is CharacterBody2D and body.is_in_group("player"):
        if body.velocity.y > 0:
            body.notify_stomp_hit()
            take_stomp_damage(1)  # inherited from BaseEnemy


func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += _gravity * delta
    velocity.x = _direction * patrol_speed
    move_and_slide()

    var distance_from_spawn := global_position.x - _spawn_position.x
    if distance_from_spawn > patrol_distance:
        _direction = -1.0
    elif distance_from_spawn < -patrol_distance:
        _direction = 1.0
    if is_on_wall():
        _direction *= -1.0
```

Removed: the local `take_stomp_damage()` method that called `queue_free()` directly. The scene `enemy_basic.tscn` needs no edits because the exported `patrol_speed`, `patrol_distance`, `hp` (inherited, defaults to 1) all resolve to the same script.

### ModifierStack (new composition object)

A plain `RefCounted` that stores the five modifier fields plus setters that clamp on write. Owned by `MovementController` as a member field. Extending `RefCounted` means the object is not in the scene tree and is freed with the controller.

```gdscript
class_name ModifierStack
extends RefCounted
## Holds equipment- and level-derived player modifiers with clamped setters.
## Owned by MovementController via composition.

var base_speed: float = 1.0
var speed_modifier: float = 0.0
var jump_height_bonus: float = 0.0
var double_jump_enabled: bool = false
var stomp_bounce_multiplier: float = 1.0


func set_base_speed(value: float) -> void:
    base_speed = clampf(value, 1.0, 1.7)


func set_speed_modifier(value: float) -> void:
    speed_modifier = clampf(value, 0.0, 0.5)


func set_jump_height_bonus(value: float) -> void:
    jump_height_bonus = clampf(value, 0.0, 1.0)


func set_double_jump_enabled(value: bool) -> void:
    double_jump_enabled = value


func set_stomp_bounce_multiplier(value: float) -> void:
    stomp_bounce_multiplier = clampf(value, 1.0, 2.0)
```

Notes:
- Fields are readable directly (`stack.base_speed`) so `MovementController` can compose them into physics formulas without an extra getter layer.
- No signals or observers: `MovementController` reads on demand each physics tick.

### MovementController (updated)

`MovementController` retains its public setter signatures and all tuning exports. Internally, the five modifier state variables are replaced by a single `ModifierStack` instance, and setters forward to the stack. The physics loop and static utility functions are unchanged.

```gdscript
class_name MovementController
extends CharacterBody2D

signal landed(impact_velocity: float)
signal stomp_bounced()

@export_group("Horizontal Movement")
@export var base_pixel_speed: float = 300.0

@export_group("Jump")
@export var jump_velocity: float = -450.0
@export var jump_cut_multiplier: float = 0.4
@export var min_jump_time: float = 0.08

@export_group("Gravity")
@export var gravity_up_multiplier: float = 1.0
@export var gravity_down_multiplier: float = 1.6
@export var terminal_velocity: float = 900.0

@export_group("Coyote Time")
@export var coyote_time_duration: float = 0.1

@export_group("Input Buffer")
@export var input_buffer_duration: float = 0.12

@export_group("Stomp Bounce")
@export var stomp_bounce_velocity: float = -350.0
@export var stomp_bounce_hold_velocity: float = -500.0

@export_group("Landing")
@export var landing_velocity_threshold: float = 200.0

# --- Composition: modifier state ---
var _modifiers: ModifierStack = ModifierStack.new()

# Existing per-frame state fields retained (coyote, jump, stomp, animation, etc.)
var _has_double_jumped: bool = false
var _coyote_timer: float = 0.0
var _was_on_floor_last_frame: bool = false
var _jump_buffer_timer: float = 0.0
var _is_jumping: bool = false
var _jump_held_time: float = 0.0
var _stomp_requested: bool = false
var _previous_velocity_y: float = 0.0
# ... walk animation state unchanged ...


# --- Public Setters (forward to ModifierStack, signatures unchanged) ---
func set_base_speed(value: float) -> void:
    _modifiers.set_base_speed(value)

func set_speed_modifier(value: float) -> void:
    _modifiers.set_speed_modifier(value)

func set_jump_height_bonus(percent: float) -> void:
    _modifiers.set_jump_height_bonus(percent)

func set_double_jump_enabled(enabled: bool) -> void:
    _modifiers.set_double_jump_enabled(enabled)

func set_stomp_bounce_multiplier(mult: float) -> void:
    _modifiers.set_stomp_bounce_multiplier(mult)


# --- Physics readers now go through _modifiers ---
func _calculate_effective_speed() -> float:
    return MovementController.calculate_effective_speed(
        base_pixel_speed,
        _modifiers.base_speed,
        _modifiers.speed_modifier
    )
```

Read sites in the existing physics loop that reference the old backing fields are rewritten:

| Old access | New access |
|---|---|
| `_base_speed` | `_modifiers.base_speed` |
| `_speed_modifier` | `_modifiers.speed_modifier` |
| `_jump_height_bonus` | `_modifiers.jump_height_bonus` |
| `_double_jump_enabled` | `_modifiers.double_jump_enabled` |
| `_stomp_bounce_multiplier` | `_modifiers.stomp_bounce_multiplier` |

Specifically:
- `_handle_jump`: `velocity.y = jump_velocity * (1.0 + _modifiers.jump_height_bonus)` in both jump-initiation branches and the buffered-jump branch in `_handle_landing`.
- `_handle_jump` / `_handle_input_buffer`: `_modifiers.double_jump_enabled` replaces `_double_jump_enabled`.
- `_handle_stomp_bounce`: `_modifiers.stomp_bounce_multiplier` replaces `_stomp_bounce_multiplier`.

Public setter signatures are byte-for-byte identical, so `LevelManager` and any equipment code that already calls `player.set_base_speed(1.2)` etc. continues to compile unchanged.

### KillZone (updated)

Simplified to a two-step handler: detect the player, delegate to `LevelManager`. The recursive checkpoint scan and direct position mutation are removed. The `respawn_position` export is retained as an unused field for scene compatibility.

```gdscript
class_name KillZone
extends Area2D
## Kills the player on contact. Delegates respawn to LevelManager.handle_player_death().
## The respawn_position export is preserved for scene compatibility only.

@export var respawn_position: Vector2 = Vector2(100, 570)  # retained but unused


func _ready() -> void:
    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
    if not (body is CharacterBody2D and body.is_in_group("player")):
        return
    if not Engine.has_singleton("LevelManager") and not _has_level_manager():
        push_error("KillZone: LevelManager autoload not available; skipping respawn.")
        return
    LevelManager.handle_player_death()


func _has_level_manager() -> bool:
    # Autoloads register as tree root children with the autoload name.
    var root := Engine.get_main_loop().root if Engine.get_main_loop() else null
    return root != null and root.has_node("LevelManager")
```

Notes:
- The autoload guard covers unit-test contexts where `LevelManager` may not be registered. Tests will inject a stand-in via a spy autoload or by temporarily replacing the node.
- Removed helpers: `_respawn_player`, `_get_last_checkpoint`, `_find_checkpoints`.

Contract with `LevelManager`:
- `LevelManager.handle_player_death()` already exists and is the authoritative respawn path used by every other death case. It sets state, invokes `checkpoint_system.get_respawn_position()`, and re-enables input. KillZone now piggybacks on that path.

## Data Models

### ModifierStack (state shape)

| Field | Type | Default | Clamp Range |
|---|---|---|---|
| `base_speed` | `float` | `1.0` | `[1.0, 1.7]` |
| `speed_modifier` | `float` | `0.0` | `[0.0, 0.5]` |
| `jump_height_bonus` | `float` | `0.0` | `[0.0, 1.0]` |
| `double_jump_enabled` | `bool` | `false` | n/a |
| `stomp_bounce_multiplier` | `float` | `1.0` | `[1.0, 2.0]` |

### BaseEnemy (state shape)

| Field | Type | Default | Notes |
|---|---|---|---|
| `hp` | `int` | `1` | exported; scene inspector can raise for tougher enemies |

### PlayerTrigger (state shape)

| Field | Type | Default | Notes |
|---|---|---|---|
| `_fired` | `bool` | `false` | internal one-shot latch |

## Error Handling

- **`LevelManager` missing at KillZone contact**: `push_error` logs a diagnostic and the trigger takes no further action. This preserves game state instead of crashing.
- **Deferred signal disconnect in `PlayerTrigger`**: the `_fired` boolean is set before the effect runs. If two bodies enter the same physics frame (before Godot dispatches the disconnect), the latch still prevents a double fire.
- **`BaseEnemy.take_stomp_damage` with negative or zero amount**: `hp -= amount` is still applied. Non-lethal amounts (zero or negative) simply won't trigger `queue_free`. Level designers can rely on positive damage in normal play; the class does not silently clamp.
- **`ModifierStack` NaN or Inf input**: `clampf` returns NaN for NaN input. The controller reads the value each physics frame; a NaN in the stack could propagate into `velocity`. Callers are expected to pass finite values. This matches pre-refactor behavior, which also did not guard against NaN.
- **`CheckpointMarker._ready` missing `super._ready()`**: this would silently break the trigger. The design's checklist for the marker refactor calls `super._ready()` explicitly; unit tests confirm the connection.

## Testing Strategy

Two complementary layers:

- **Unit tests (GdUnit4)** for each new class in isolation. Property-based iteration is used where the state space is large enough to justify it (clamping, damage arithmetic, one-shot latch).
- **Integration tests (GdUnit4)** for scene-load smoke checks (`floor_1.tscn` opens) and one scripted playthrough covering movement, jump, stomp, and kill zone flow.

Test files:
- `tests/base_enemy_test.gd` — unit tests for HP semantics and queue_free.
- `tests/modifier_stack_test.gd` — unit tests for clamping and toggling.
- `tests/player_trigger_test.gd` — unit tests for one-shot activation.
- `tests/kill_zone_test.gd` — unit tests for delegation to a stubbed `LevelManager`.
- `tests/movement_controller_integration_test.gd` — smoke test that setter forwarding lands correct values in the stack.
- `tests/floor_1_smoke_test.gd` — asserts `floor_1.tscn` loads and instantiates without errors.

Property test configuration:
- Minimum 100 iterations per property.
- Random float generators use a wide range (e.g. `[-100.0, 100.0]`) so both clamp branches are exercised.
- Each property test's docstring or annotation cites its design property number.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: BaseEnemy damage semantics

For any `BaseEnemy` instance with any non-negative starting `hp` and any integer `amount`, after invoking `take_stomp_damage(amount)`:
- the field `hp` equals the starting value minus `amount`, and
- the instance is queued for deletion if and only if the resulting `hp` is less than or equal to zero.

**Validates: Requirements 1.2, 1.3**

### Property 2: ModifierStack.base_speed clamp

For any float value `v`, after calling `ModifierStack.set_base_speed(v)`, the stored `base_speed` equals `clampf(v, 1.0, 1.7)` and lies in `[1.0, 1.7]`.

**Validates: Requirements 2.3**

### Property 3: ModifierStack.speed_modifier clamp

For any float value `v`, after calling `ModifierStack.set_speed_modifier(v)`, the stored `speed_modifier` equals `clampf(v, 0.0, 0.5)` and lies in `[0.0, 0.5]`.

**Validates: Requirements 2.4**

### Property 4: ModifierStack.jump_height_bonus clamp

For any float value `v`, after calling `ModifierStack.set_jump_height_bonus(v)`, the stored `jump_height_bonus` equals `clampf(v, 0.0, 1.0)` and lies in `[0.0, 1.0]`.

**Validates: Requirements 2.5**

### Property 5: ModifierStack.stomp_bounce_multiplier clamp

For any float value `v`, after calling `ModifierStack.set_stomp_bounce_multiplier(v)`, the stored `stomp_bounce_multiplier` equals `clampf(v, 1.0, 2.0)` and lies in `[1.0, 2.0]`.

**Validates: Requirements 2.6**

### Property 6: MovementController forwards setter calls to ModifierStack

For any float value `v` and any of the five forwarded setters on `MovementController` (`set_base_speed`, `set_speed_modifier`, `set_jump_height_bonus`, `set_double_jump_enabled`, `set_stomp_bounce_multiplier`), after invoking the controller setter, the corresponding field on the owned `ModifierStack` equals the value that the stack's own setter would have stored for the same input.

**Validates: Requirements 2.8, 2.9**

### Property 7: PlayerTrigger one-shot activation

For any sequence of two or more `CharacterBody2D` bodies in the `player` group entering the same `PlayerTrigger` instance, the virtual `_on_player_entered` method is invoked exactly once, on the first body in the sequence.

**Validates: Requirements 3.2, 3.3**