# Implementation Plan: Player Core Movement

## Overview

Replace the current simple `scripts/player.gd` with a full-featured `MovementController` script implementing instant horizontal movement, variable-height jumps, gravity with asymmetric multipliers, stomp bounce, coyote time, input buffering, landing events, and equipment/level-driven modifiers. Pure/static utility functions are extracted for testability with GdUnit4 property-based tests.

## Tasks

- [x] 1. Set up project structure and core interfaces
  - [x] 1.1 Create MovementController script with exported parameters and signals
    - Create `scripts/movement_controller.gd` with `class_name MovementController` extending `CharacterBody2D`
    - Define all `@export` groups and variables as specified in the design (Horizontal Movement, Jump, Gravity, Coyote Time, Input Buffer, Stomp Bounce, Landing)
    - Define signals: `landed(impact_velocity: float)`, `stomp_bounced()`
    - Define all internal state variables (`_base_speed`, `_speed_modifier`, `_jump_height_bonus`, `_double_jump_enabled`, `_has_double_jumped`, `_stomp_bounce_multiplier`, `_coyote_timer`, `_was_on_floor_last_frame`, `_jump_buffer_timer`, `_is_jumping`, `_jump_held_time`, `_stomp_requested`, `_previous_velocity_y`)
    - Define the public setter method signatures: `set_base_speed()`, `set_speed_modifier()`, `set_jump_height_bonus()`, `set_double_jump_enabled()`, `set_stomp_bounce_multiplier()`, `notify_stomp_hit()`
    - _Requirements: 1.1, 1.3, 2.1, 3.1, 3.2, 4.4, 5.1, 6.1, 7.1, 8.1, 8.6_

  - [x] 1.2 Implement static utility functions for testability
    - Implement `static func calculate_effective_speed(base_pixel_speed: float, base_speed: float, speed_modifier: float) -> float` returning `base_pixel_speed * (base_speed + speed_modifier)`
    - Implement `static func apply_gravity(current_vy: float, gravity: float, multiplier: float, delta: float, terminal: float) -> float` returning `min(current_vy + gravity * multiplier * delta, terminal)`
    - Implement `static func apply_jump_cut(current_vy: float, cut_multiplier: float) -> float` returning `current_vy * cut_multiplier`
    - Implement `static func interpolate_base_speed(level: int) -> float` clamping level to [1, 15] and returning `1.0 + (level - 1) * (0.7 / 14.0)`
    - _Requirements: 1.3, 2.3, 3.1, 3.2, 9.1, 9.3_

  - [x] 1.3 Set up GdUnit4 test directory structure
    - Create `test/` directory at project root for GdUnit4 tests
    - Create `test/movement/` subdirectory for movement-related tests
    - Ensure `.gdunit4.cfg` or equivalent configuration file exists (if GdUnit4 plugin is installed)
    - _Requirements: All (testing infrastructure)_

- [x] 2. Implement horizontal movement and speed system
  - [x] 2.1 Implement instant horizontal movement logic
    - Implement `_handle_horizontal_movement()` reading `move_left`/`move_right` input actions
    - Apply `direction * _calculate_effective_speed()` instantly (no acceleration ramp)
    - Set `velocity.x = 0` when no direction input is active (instant stop, no deceleration)
    - Ensure same behavior applies in both Ground_State and Air_State
    - _Requirements: 1.1, 1.2, 1.4, 1.5_

  - [x] 2.2 Implement effective speed calculation and modifier setters
    - Implement `_calculate_effective_speed() -> float` calling the static utility function with instance variables
    - Implement `set_speed_modifier(value: float)` with clamping to [0.0, 0.5]
    - Implement `set_base_speed(value: float)` with clamping to [1.0, 1.7]
    - Implement `set_jump_height_bonus(percent: float)` with clamping to [0.0, 1.0]
    - Implement `set_stomp_bounce_multiplier(mult: float)` with clamping to [1.0, 2.0]
    - Implement `set_double_jump_enabled(enabled: bool)`
    - _Requirements: 1.3, 8.1, 8.2, 8.3, 8.4, 8.6, 9.1, 9.2_

  - [ ]* 2.3 Write property tests for effective speed and level interpolation
    - **Property 1: Effective Speed Calculation** — For random direction ∈ {-1, 0, 1}, base_speed ∈ [1.0, 1.7], speed_modifier ∈ [0.0, 0.5], verify result equals `direction * base_pixel_speed * (base_speed + speed_modifier)`
    - **Property 10: Speed Modifier Clamping** — For random values outside [0.0, 0.5], verify stored value is clamped
    - **Property 11: Level-to-Speed Linear Interpolation** — For random level ∈ [1, 15], verify result equals `1.0 + (level - 1) * (0.7 / 14.0)`
    - Create `test/movement/test_speed_properties.gd` using GdUnit4 fuzzers or manual randomization (100+ iterations)
    - **Validates: Requirements 1.1, 1.3, 8.1, 8.6, 9.1, 9.3**

- [x] 3. Implement jump system with variable height
  - [x] 3.1 Implement basic jump and variable-height logic
    - Implement `_handle_jump()` applying `jump_velocity * (1.0 + _jump_height_bonus)` on jump button press when on floor
    - Track `_is_jumping` and `_jump_held_time` for minimum jump time guarantee
    - Apply jump cut (`velocity.y *= jump_cut_multiplier`) when button released early and `_jump_held_time > min_jump_time`
    - Only allow jump cut while ascending (velocity.y < 0)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 8.4_

  - [x] 3.2 Implement double jump logic
    - Within `_handle_jump()`, allow one additional jump in Air_State when `_double_jump_enabled` is true and `_has_double_jumped` is false
    - Set `_has_double_jumped = true` after using the double jump
    - Reset `_has_double_jumped = false` on landing (in `_handle_landing()`)
    - _Requirements: 8.5_

  - [ ]* 3.3 Write property tests for jump mechanics
    - **Property 2: Jump Cut Reduces Velocity** — For random ascending velocity (negative) and cut_multiplier ∈ (0.0, 1.0), verify result equals `current_vy * cut_multiplier` and is closer to zero
    - **Property 9: Jump Height Bonus Scaling** — For random jump_velocity (negative) and bonus ∈ [0.0, 1.0], verify effective impulse equals `jump_velocity * (1.0 + bonus)`
    - Create `test/movement/test_jump_properties.gd` using GdUnit4 fuzzers (100+ iterations)
    - **Validates: Requirements 2.3, 8.4**

- [x] 4. Implement gravity system
  - [x] 4.1 Implement gravity with asymmetric multipliers and terminal velocity
    - Implement `_handle_gravity(delta)` using the static `apply_gravity()` function
    - Select `gravity_up_multiplier` when `velocity.y < 0` (ascending) and `gravity_down_multiplier` when `velocity.y >= 0` (descending)
    - Cap velocity at `terminal_velocity`
    - Only apply gravity when player is in Air_State (not on floor)
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 4.2 Write property tests for gravity
    - **Property 3: Gravity Application with Terminal Velocity** — For random current_vy, gravity, multiplier, delta, verify result equals `min(current_vy + gravity * multiplier * delta, terminal)`
    - **Property 4: Asymmetric Gravity Selection** — For random velocity, verify correct multiplier is selected (down_multiplier for positive vy, up_multiplier for negative vy, and down > up)
    - Create `test/movement/test_gravity_properties.gd` using GdUnit4 fuzzers (100+ iterations)
    - **Validates: Requirements 3.1, 3.2, 3.3**

- [x] 5. Checkpoint - Core movement verified
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement coyote time and input buffer
  - [x] 6.1 Implement coyote time logic
    - Implement `_handle_coyote_time(delta)` detecting floor-to-air transition without jump
    - Start `_coyote_timer = coyote_time_duration` on walk-off edge
    - Decrement timer each physics frame; allow jump while timer > 0
    - Consume coyote time immediately on jump execution (set timer to 0)
    - Track `_was_on_floor_last_frame` for transition detection
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 6.2 Implement input buffer logic
    - Implement `_handle_input_buffer(delta)` storing jump press when in air and cannot jump
    - Set `_jump_buffer_timer = input_buffer_duration` on jump press in air
    - Decrement timer each physics frame; discard when expired
    - Execute buffered jump immediately on landing (in `_handle_landing()`)
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ]* 6.3 Write property tests for coyote time and input buffer
    - **Property 6: Coyote Timer Expiration** — For random coyote_time_duration and sequence of deltas summing >= duration, verify timer <= 0 after processing
    - **Property 7: Input Buffer Expiration** — For random input_buffer_duration and sequence of deltas summing >= duration, verify buffer is discarded (timer <= 0)
    - Create `test/movement/test_timers_properties.gd` using GdUnit4 fuzzers (100+ iterations)
    - **Validates: Requirements 5.3, 6.3**

- [x] 7. Implement stomp bounce and landing events
  - [x] 7.1 Implement stomp bounce handler
    - Implement `notify_stomp_hit()` setting `_stomp_requested = true`
    - Implement `_handle_stomp_bounce()` applying `stomp_bounce_velocity * _stomp_bounce_multiplier` when stomp is requested
    - If jump button is held during stomp, use `stomp_bounce_hold_velocity * _stomp_bounce_multiplier` instead
    - Only process stomp when in Air_State; ignore if on floor
    - Process only first stomp request per frame; reset `_stomp_requested` after processing
    - Emit `stomp_bounced` signal after applying bounce
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 7.2 Implement landing detection and event emission
    - Implement `_handle_landing()` detecting air-to-ground transition using `is_on_floor()` and `_was_on_floor_last_frame`
    - Track `_previous_velocity_y` before `move_and_slide()`
    - Emit `landed` signal only when `_previous_velocity_y > landing_velocity_threshold`
    - Reset `_has_double_jumped`, consume input buffer on landing
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ]* 7.3 Write property tests for stomp bounce and landing
    - **Property 5: Stomp Bounce Multiplier Scaling** — For random stomp_bounce_velocity and multiplier ∈ [1.0, 2.0], verify result equals `stomp_bounce_velocity * multiplier`
    - **Property 8: Landing Event Threshold Filter** — For random previous_velocity_y and threshold, verify landing event emits iff `previous_velocity_y > threshold`
    - Create `test/movement/test_stomp_landing_properties.gd` using GdUnit4 fuzzers (100+ iterations)
    - **Validates: Requirements 4.4, 7.3**

- [x] 8. Wire _physics_process and integrate with scene
  - [x] 8.1 Implement the main _physics_process loop
    - Implement `_physics_process(delta)` calling all handler methods in correct order:
      1. `_handle_coyote_time(delta)`
      2. `_handle_input_buffer(delta)`
      3. `_handle_horizontal_movement()`
      4. `_handle_jump()`
      5. `_handle_gravity(delta)`
      6. `_handle_stomp_bounce()`
      7. Store `_previous_velocity_y = velocity.y`
      8. `move_and_slide()`
      9. `_handle_landing()`
    - Preserve existing sprite flip logic (`$Sprite2D.flip_h` based on direction)
    - Preserve existing procedural walk animation (`_animate_walk`)
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1_

  - [x] 8.2 Update player scene to use MovementController
    - Update `scenes/player.tscn` to reference `scripts/movement_controller.gd` instead of `scripts/player.gd`
    - Verify exported variables are visible in the Inspector
    - Ensure input actions (`move_left`, `move_right`, `jump`) are defined in `project.godot` Input Map
    - _Requirements: All (integration)_

- [x] 9. Checkpoint - Full integration verified
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Write unit tests for integration scenarios
  - [ ]* 10.1 Write unit tests for jump, coyote time, and input buffer integration
    - Test jump initiation on ground succeeds (2.1)
    - Test minimum jump time guarantee (2.4)
    - Test coyote time activates on edge walk-off (5.1)
    - Test jump during coyote time succeeds (5.2)
    - Test coyote time consumed after jump (5.4)
    - Test input buffer stores request in air (6.1)
    - Test buffered jump fires on landing (6.2)
    - Test double jump: one extra allowed, second denied, reset on landing (8.5)
    - Create `test/movement/test_movement_integration.gd`
    - _Requirements: 2.1, 2.4, 5.1, 5.2, 5.4, 6.1, 6.2, 8.5_

  - [ ]* 10.2 Write unit tests for stomp, landing, and direction changes
    - Test stomp bounce application in air (4.1)
    - Test stomp bounce with held jump gives enhanced bounce (4.3)
    - Test landing signal emission above threshold (7.1, 7.3)
    - Test landing signal NOT emitted below threshold (7.3)
    - Test direction reversal is instant (1.5)
    - Test stop on direction release (1.2)
    - Create `test/movement/test_movement_scenarios.gd`
    - _Requirements: 1.2, 1.5, 4.1, 4.3, 7.1, 7.3_

- [x] 11. Final checkpoint - All tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties using GdUnit4 fuzzers or manual `randf_range()`/`randi_range()` loops (100+ iterations)
- Unit tests validate specific examples and edge cases
- The existing `scripts/player.gd` is preserved until `movement_controller.gd` is wired to the scene in task 8.2
- Static utility functions enable testing without Godot node instantiation

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1", "2.2"] },
    { "id": 3, "tasks": ["2.3", "3.1", "4.1"] },
    { "id": 4, "tasks": ["3.2", "3.3", "4.2"] },
    { "id": 5, "tasks": ["6.1", "6.2"] },
    { "id": 6, "tasks": ["6.3", "7.1", "7.2"] },
    { "id": 7, "tasks": ["7.3", "8.1"] },
    { "id": 8, "tasks": ["8.2"] },
    { "id": 9, "tasks": ["10.1", "10.2"] }
  ]
}
```
