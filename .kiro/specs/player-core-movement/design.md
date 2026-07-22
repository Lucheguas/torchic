# Design Document: Player Core Movement

## Overview

This design describes the architecture and implementation of the core player movement system for Torchic, a 2D pixel art platformer built on Godot 4.7 with GDScript. The system replaces the current simple movement script (`player.gd`) with a modular, data-driven movement controller that supports:

- Instant horizontal movement (zero acceleration/deceleration)
- Variable-height jumps with gravity multipliers
- Stomp bounce with configurable multipliers
- Coyote time and input buffering for forgiving jump mechanics
- Landing event emission for animation feedback
- Equipment-driven speed modifiers and ability unlocks (double jump)
- Level-based base speed scaling

The design prioritizes frame-perfect responsiveness, clean separation between physics logic and external systems (equipment, leveling), and testability of the movement math independent of the Godot engine.

## Architecture

The movement system follows a **single-script controller** pattern attached to the existing `CharacterBody2D` node. Rather than splitting into many small scripts (which adds indirection in GDScript without benefit for this scope), we use one `MovementController` script with clearly separated internal methods grouped by responsibility.

External systems communicate with the controller through:
- **Signals** (outbound): `landed`, `stomp_bounced`
- **Setter methods** (inbound): `set_speed_modifier()`, `set_base_speed()`, `set_jump_height_bonus()`, `set_double_jump_enabled()`, `set_stomp_bounce_multiplier()`

```mermaid
graph TD
    subgraph Player Node (CharacterBody2D)
        MC[MovementController Script]
        MC --> HM[Horizontal Movement]
        MC --> VM[Vertical Movement / Jump]
        MC --> GT[Gravity & Terminal Velocity]
        MC --> CT[Coyote Time Timer]
        MC --> IB[Input Buffer Timer]
        MC --> SB[Stomp Bounce Handler]
        MC --> LE[Landing Event Emitter]
    end

    subgraph External Systems
        EQ[Equipment System]
        LVL[Level / Progression System]
        ENEMY[Enemy Collision System]
        ANIM[Animation Controller]
    end

    EQ -- set_speed_modifier / set_jump_height_bonus / set_double_jump_enabled / set_stomp_bounce_multiplier --> MC
    LVL -- set_base_speed --> MC
    ENEMY -- notify_stomp_hit --> MC
    MC -- signal: landed --> ANIM
    MC -- signal: stomp_bounced --> ANIM
```

### Design Decisions

1. **Single script, not a state machine**: The movement requirements are tightly coupled (gravity applies in all air states, input buffer fires on landing regardless of jump source). A flat controller with boolean flags (`_is_coyote_active`, `_has_double_jumped`) is simpler and more performant than a formal FSM for this scope.

2. **Pure math functions for testability**: Speed calculation, gravity application, and jump height logic are extracted into static/pure helper functions that can be unit tested without instantiating a Godot node.

3. **Configurable via exported variables**: All tuning parameters (jump velocity, gravity multiplier, coyote time duration, buffer window, terminal velocity) are `@export` vars editable in the Inspector for rapid iteration.

4. **Timer-free approach**: Instead of `Timer` nodes, coyote time and input buffer use simple float counters decremented each physics frame. This avoids node overhead and is deterministic across frame rates (since `_physics_process` runs at fixed rate).

## Components and Interfaces

### MovementController (scripts/player.gd replacement)

```gdscript
class_name MovementController
extends CharacterBody2D

# --- Signals ---
signal landed(impact_velocity: float)
signal stomp_bounced()

# --- Exported Tuning Parameters ---
@export_group("Horizontal Movement")
@export var base_pixel_speed: float = 300.0  # Pixels/sec at speed 1.0

@export_group("Jump")
@export var jump_velocity: float = -450.0      # Initial upward impulse (negative = up)
@export var jump_cut_multiplier: float = 0.4   # Applied when button released early
@export var min_jump_time: float = 0.08        # Seconds of guaranteed jump force

@export_group("Gravity")
@export var gravity_up_multiplier: float = 1.0
@export var gravity_down_multiplier: float = 1.6
@export var terminal_velocity: float = 900.0

@export_group("Coyote Time")
@export var coyote_time_duration: float = 0.1  # 100ms

@export_group("Input Buffer")
@export var input_buffer_duration: float = 0.12  # 120ms

@export_group("Stomp Bounce")
@export var stomp_bounce_velocity: float = -350.0
@export var stomp_bounce_hold_velocity: float = -500.0

@export_group("Landing")
@export var landing_velocity_threshold: float = 200.0
```

### Public Interface (Setters for External Systems)

| Method | Parameters | Description |
|--------|-----------|-------------|
| `set_base_speed(value: float)` | `value`: 1.0–1.7 | Sets the level-based speed multiplier |
| `set_speed_modifier(value: float)` | `value`: 0.0–0.5 | Sets the equipment speed bonus |
| `set_jump_height_bonus(percent: float)` | `percent`: 0.0–1.0 | Scales jump velocity (e.g., 0.05 = +5%) |
| `set_double_jump_enabled(enabled: bool)` | `enabled` | Enables/disables double jump |
| `set_stomp_bounce_multiplier(mult: float)` | `mult`: 1.0–2.0 | Scales stomp bounce velocity |
| `notify_stomp_hit()` | — | Called by enemy collision; triggers bounce |

### Internal Methods (Private)

| Method | Responsibility |
|--------|---------------|
| `_handle_horizontal_movement()` | Reads input, applies instant velocity |
| `_handle_jump()` | Jump initiation, variable height, double jump |
| `_handle_gravity(delta)` | Applies gravity with up/down multipliers |
| `_handle_coyote_time(delta)` | Manages coyote timer countdown |
| `_handle_input_buffer(delta)` | Manages input buffer countdown |
| `_handle_landing()` | Detects ground transition, emits signal |
| `_handle_stomp_bounce()` | Applies bounce velocity on stomp notification |
| `_calculate_effective_speed() -> float` | Returns `base_pixel_speed * (base_speed + speed_modifier)` |

### Utility / Pure Functions (for testing)

```gdscript
static func calculate_effective_speed(base_pixel_speed: float, base_speed: float, speed_modifier: float) -> float
static func apply_gravity(current_vy: float, gravity: float, multiplier: float, delta: float, terminal: float) -> float
static func apply_jump_cut(current_vy: float, cut_multiplier: float) -> float
static func interpolate_base_speed(level: int) -> float
```

## Data Models

### Movement State (Internal)

```gdscript
# Runtime state tracked per frame
var _base_speed: float = 1.0
var _speed_modifier: float = 0.0
var _jump_height_bonus: float = 0.0
var _double_jump_enabled: bool = false
var _has_double_jumped: bool = false
var _stomp_bounce_multiplier: float = 1.0

# Coyote time
var _coyote_timer: float = 0.0
var _was_on_floor_last_frame: bool = false

# Input buffer
var _jump_buffer_timer: float = 0.0

# Jump tracking
var _is_jumping: bool = false
var _jump_held_time: float = 0.0

# Stomp
var _stomp_requested: bool = false

# Landing detection
var _previous_velocity_y: float = 0.0
```

### Speed Progression Table

The base speed values from the GDD map linearly between defined levels:

| Level | Base Speed |
|-------|-----------|
| 1 | 1.0 |
| 3 | 1.1 |
| 5 | 1.2 |
| 7 | 1.3 |
| 9 | 1.4 |
| 11 | 1.5 |
| 13 | 1.6 |
| 15 | 1.7 |

Linear interpolation formula: `base_speed = 1.0 + (level - 1) * (0.7 / 14.0)`

This yields exact GDD values at defined levels and smooth transitions between them.

### Equipment Speed Modifiers (from GDD)

| Equipment | Speed Modifier | Jump Bonus | Special |
|-----------|---------------|------------|---------|
| Botas de Tela | +0.1 | — | — |
| Botas de Cuero Reforzado | +0.2 | +5% jump height | — |
| Botas Furia de Viento | +0.35 | — | Double Jump (short) |
| Botas Gravitacionales | +0.5 | — | Stomp bounce ×2 |



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Effective Speed Calculation

*For any* direction (-1, 0, or 1), base_speed in [1.0, 1.7], and speed_modifier in [0.0, 0.5], the resulting horizontal velocity SHALL equal `direction * base_pixel_speed * (base_speed + speed_modifier)`, regardless of whether the character is on the ground or in the air.

**Validates: Requirements 1.1, 1.3, 1.4, 1.5, 8.1**

### Property 2: Jump Cut Reduces Velocity

*For any* ascending velocity (negative value) and cut_multiplier in (0.0, 1.0), applying jump cut SHALL produce a velocity equal to `current_vy * cut_multiplier`, resulting in a value closer to zero (less negative) than the original.

**Validates: Requirements 2.3**

### Property 3: Gravity Application with Terminal Velocity

*For any* current vertical velocity, gravity value, multiplier, and delta, applying gravity SHALL produce `min(current_vy + gravity * multiplier * delta, terminal_velocity)` — the velocity increases toward terminal but never exceeds it.

**Validates: Requirements 3.1, 3.2**

### Property 4: Asymmetric Gravity Selection

*For any* frame where the character is airborne, if the vertical velocity is positive (descending) the gravity_down_multiplier SHALL be used, and if the vertical velocity is negative (ascending) the gravity_up_multiplier SHALL be used, where gravity_down_multiplier > gravity_up_multiplier.

**Validates: Requirements 3.3**

### Property 5: Stomp Bounce Multiplier Scaling

*For any* stomp_bounce_velocity and stomp_bounce_multiplier in [1.0, 2.0], the applied bounce velocity SHALL equal `stomp_bounce_velocity * stomp_bounce_multiplier`.

**Validates: Requirements 4.4**

### Property 6: Coyote Timer Expiration

*For any* coyote_time_duration and sequence of elapsed deltas whose sum >= coyote_time_duration, after processing those deltas the coyote timer SHALL be <= 0 and jumping SHALL be disallowed (unless on floor or double jump is available).

**Validates: Requirements 5.3**

### Property 7: Input Buffer Expiration

*For any* input_buffer_duration and sequence of elapsed deltas whose sum >= input_buffer_duration without landing, the buffered jump request SHALL be discarded (buffer timer <= 0).

**Validates: Requirements 6.3**

### Property 8: Landing Event Threshold Filter

*For any* previous vertical velocity and landing_velocity_threshold, the landing event SHALL be emitted if and only if `previous_velocity_y > landing_velocity_threshold`.

**Validates: Requirements 7.3**

### Property 9: Jump Height Bonus Scaling

*For any* base jump_velocity and jump_height_bonus in [0.0, 1.0], the effective jump impulse SHALL equal `jump_velocity * (1.0 + jump_height_bonus)`.

**Validates: Requirements 8.4**

### Property 10: Speed Modifier Clamping

*For any* input value passed to set_speed_modifier, the stored speed_modifier SHALL be clamped to the range [0.0, 0.5].

**Validates: Requirements 8.6**

### Property 11: Level-to-Speed Linear Interpolation

*For any* player level in [1, 15], the base_speed SHALL equal `1.0 + (level - 1) * (0.7 / 14.0)`, yielding exactly 1.0 at level 1 and 1.7 at level 15.

**Validates: Requirements 9.1, 9.3**

## Error Handling

### Invalid Input Values

| Scenario | Handling |
|----------|----------|
| `set_speed_modifier` receives value < 0.0 | Clamp to 0.0 |
| `set_speed_modifier` receives value > 0.5 | Clamp to 0.5 |
| `set_base_speed` receives value outside [1.0, 1.7] | Clamp to valid range |
| `set_jump_height_bonus` receives negative value | Clamp to 0.0 |
| `set_stomp_bounce_multiplier` receives value < 1.0 | Clamp to 1.0 |
| `interpolate_base_speed` receives level < 1 or > 15 | Clamp level to [1, 15] |
| `notify_stomp_hit` called while on ground | Ignore (no bounce applied) |
| Multiple `notify_stomp_hit` in same frame | Process only the first |

### Edge Cases

- **Zero delta**: If `_physics_process` receives delta = 0, timers don't decrement and gravity doesn't apply. No special handling needed — math naturally produces no change.
- **Extremely high velocity from external forces**: Terminal velocity clamp applies regardless of source.
- **Simultaneous coyote jump + input buffer**: If both are active on the same frame, execute the buffered jump (coyote provides the permission, buffer provides the request).

## Testing Strategy

### Unit Tests (Example-Based)

Unit tests cover specific scenarios, integration points, and edge cases:

- Jump initiation on ground (2.1)
- Jump sustain while held (2.2)
- Minimum jump time guarantee (2.4)
- Stomp bounce application (4.1)
- Stomp bounce with held jump gives enhanced bounce (4.3)
- Coyote time activation on edge walk-off (5.1)
- Jump during coyote time succeeds (5.2)
- Coyote time consumed after jump (5.4)
- Input buffer stores request in air (6.1)
- Buffered jump fires on landing (6.2)
- Landing signal emission (7.1)
- Double jump: one extra jump allowed, second denied, reset on landing (8.5)
- Direction reversal is instant (1.5)
- Stop on direction release (1.2)
- set_speed_modifier / set_base_speed update internal state (8.2, 8.3, 9.2)

### Property-Based Tests

Property-based tests validate the 11 correctness properties above using **GdUnit4** with its built-in fuzzer capabilities, or alternatively a custom lightweight property test harness in GDScript that generates random inputs over 100+ iterations per property.

**Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with: `Feature: player-core-movement, Property {N}: {title}`
- Tests exercise pure/static functions (no Godot node instantiation needed)

**Library choice:** GdUnit4 (Godot-native testing framework with `Fuzzers` support for property-based generation). If GdUnit4 is not available, a simple `for i in range(100)` loop with `randf_range()` / `randi_range()` achieves the same effect for these pure math functions.

**Property test targets:**
| Property | Function Under Test |
|----------|-------------------|
| 1: Effective Speed | `calculate_effective_speed()` |
| 2: Jump Cut | `apply_jump_cut()` |
| 3: Gravity + Terminal | `apply_gravity()` |
| 4: Asymmetric Gravity | Multiplier selection logic |
| 5: Stomp Scaling | Bounce calculation |
| 6: Coyote Expiration | Timer countdown logic |
| 7: Buffer Expiration | Timer countdown logic |
| 8: Landing Threshold | Threshold comparison |
| 9: Jump Bonus | Jump velocity scaling |
| 10: Speed Clamping | `set_speed_modifier()` clamping |
| 11: Level Interpolation | `interpolate_base_speed()` |

### Integration Tests

- Equipment system calls `set_speed_modifier` → movement speed changes observed
- Level-up system calls `set_base_speed` → movement speed changes observed
- Enemy collision calls `notify_stomp_hit` → bounce occurs
- Landing signal triggers animation system
