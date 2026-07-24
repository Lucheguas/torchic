# Implementation Plan: OOP Refactors

## Overview

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

Implementation follows the priority order established in the requirements document: HIGH (BaseEnemy, ModifierStack) → MEDIUM (PlayerTrigger) → LOW (KillZone delegation), with a final backward-compatibility smoke test against `floor_1.tscn`. All work is GDScript targeting Godot 4.7, and unit tests are written using GdUnit4 (already configured via `.gdunit4.cfg`).

## Tasks

- [ ] 1. HIGH — Introduce `BaseEnemy` and refactor `EnemyBasic`
  - [ ] 1.1 Create `scripts/enemies/base_enemy.gd` with the `BaseEnemy` class
    - Extend `CharacterBody2D`, declare `class_name BaseEnemy`
    - Add `@export var hp: int = 1`
    - Add `take_stomp_damage(amount: int = 1)` that subtracts and calls `queue_free()` when `hp <= 0`
    - _Requirements: 1.1, 1.2, 1.3_

  - [ ] 1.2 Refactor `scripts/enemy_basic.gd` to extend `BaseEnemy`
    - Change base from `CharacterBody2D` to `BaseEnemy`, keep `class_name EnemyBasic`
    - Remove the local `take_stomp_damage()` method; call inherited `take_stomp_damage(1)` from the stomp handler
    - Preserve `patrol_speed`, `patrol_distance`, gravity, and `StompArea` wiring exactly as in the current script
    - _Requirements: 1.4, 1.5, 1.6, 5.1, 5.2_

  - [ ]* 1.3 Write property test for `BaseEnemy` damage semantics
    - Create `tests/base_enemy_test.gd`
    - **Property 1: BaseEnemy damage semantics** — for any starting `hp` and integer `amount`, after `take_stomp_damage(amount)` the field equals `starting_hp - amount` and the node is queued for deletion iff resulting `hp <= 0`
    - Use GdUnit4 fuzzing with at least 100 iterations over the input space
    - **Validates: Requirements 1.2, 1.3**

  - [ ]* 1.4 Write unit tests for `BaseEnemy`
    - Cover: HP subtraction with positive amounts, non-lethal hit preserves HP above zero, lethal hit calls `queue_free`
    - _Requirements: 6.1_

- [ ] 2. HIGH — Introduce `ModifierStack` and refactor `MovementController`
  - [ ] 2.1 Create `scripts/modifier_stack.gd` with the `ModifierStack` class
    - Extend `RefCounted`, declare `class_name ModifierStack`
    - Add fields: `base_speed`, `speed_modifier`, `jump_height_bonus`, `double_jump_enabled`, `stomp_bounce_multiplier`
    - Add clamped setters per the design's clamp table
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ]* 2.2 Write property test for `ModifierStack.set_base_speed` clamp
    - Add to `tests/modifier_stack_test.gd`
    - **Property 2: ModifierStack.base_speed clamp** — for any float `v`, after `set_base_speed(v)` the stored value equals `clampf(v, 1.0, 1.7)` and lies in `[1.0, 1.7]`
    - **Validates: Requirements 2.3**

  - [ ]* 2.3 Write property test for `ModifierStack.set_speed_modifier` clamp
    - **Property 3: ModifierStack.speed_modifier clamp** — for any float `v`, after `set_speed_modifier(v)` the stored value equals `clampf(v, 0.0, 0.5)` and lies in `[0.0, 0.5]`
    - **Validates: Requirements 2.4**

  - [ ]* 2.4 Write property test for `ModifierStack.set_jump_height_bonus` clamp
    - **Property 4: ModifierStack.jump_height_bonus clamp** — for any float `v`, after `set_jump_height_bonus(v)` the stored value equals `clampf(v, 0.0, 1.0)` and lies in `[0.0, 1.0]`
    - **Validates: Requirements 2.5**

  - [ ]* 2.5 Write property test for `ModifierStack.set_stomp_bounce_multiplier` clamp
    - **Property 5: ModifierStack.stomp_bounce_multiplier clamp** — for any float `v`, after `set_stomp_bounce_multiplier(v)` the stored value equals `clampf(v, 1.0, 2.0)` and lies in `[1.0, 2.0]`
    - **Validates: Requirements 2.6**

  - [ ]* 2.6 Write unit tests for `ModifierStack.set_double_jump_enabled`
    - Add to `tests/modifier_stack_test.gd`
    - Assert toggle behavior with `true` and `false` inputs
    - _Requirements: 6.2_

  - [ ] 2.7 Refactor `scripts/movement_controller.gd` to own a `ModifierStack`
    - Replace the five backing modifier fields with `var _modifiers: ModifierStack = ModifierStack.new()`
    - Rewrite each public setter (`set_base_speed`, `set_speed_modifier`, `set_jump_height_bonus`, `set_double_jump_enabled`, `set_stomp_bounce_multiplier`) to forward to `_modifiers`
    - Update the physics loop and helpers (`_calculate_effective_speed`, `_handle_jump`, `_handle_input_buffer`, `_handle_landing`, `_handle_stomp_bounce`) to read from `_modifiers.*`
    - Keep public setter signatures, exported fields, signals, and static utilities byte-identical
    - _Requirements: 2.7, 2.8, 2.9, 2.10, 5.1, 5.2_

  - [ ]* 2.8 Write property test for `MovementController` setter forwarding
    - Create `tests/movement_controller_integration_test.gd`
    - **Property 6: MovementController forwards setter calls to ModifierStack** — for any float `v` and any of the five forwarded setters, invoking the controller setter results in the same stored value on `_modifiers` that the stack's own setter would produce
    - Use a test double that exposes `_modifiers` for inspection (test-only accessor or reflection via `get`)
    - **Validates: Requirements 2.8, 2.9**

- [ ] 3. Checkpoint — Ensure HIGH-priority refactors compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. MEDIUM — Introduce `PlayerTrigger` and refactor three subclasses
  - [ ] 4.1 Create `scripts/triggers/player_trigger.gd` with the `PlayerTrigger` base class
    - Extend `Area2D`, declare `class_name PlayerTrigger`
    - Connect `body_entered` in `_ready` (guarded by `is_connected`)
    - Filter for `CharacterBody2D` in `player` group, latch `_fired`, invoke virtual `_on_player_entered(body)`, disconnect handler
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 4.2 Write property test for `PlayerTrigger` one-shot activation
    - Create `tests/player_trigger_test.gd`
    - **Property 7: PlayerTrigger one-shot activation** — for any sequence of two or more player bodies entering the same trigger, `_on_player_entered` is invoked exactly once, on the first body
    - Use a subclass stub that counts invocations and captures the body reference
    - **Validates: Requirements 3.2, 3.3**

  - [ ]* 4.3 Write unit tests for `PlayerTrigger` non-player rejection
    - Assert non-player bodies (e.g. plain `Node2D`, `CharacterBody2D` not in `player` group) do not fire the trigger and do not consume the one-shot
    - _Requirements: 3.2, 6.3_

  - [ ] 4.4 Refactor `scripts/level_system/transition_trigger.gd` to extend `PlayerTrigger`
    - Change base class, keep `class_name TransitionTrigger`
    - Remove the local `_ready` and `_on_body_entered`
    - Implement `_on_player_entered(_body)` that emits `triggered.emit(self)`
    - Preserve `target_type`, `sublevel_config`, `transition_visual` exports and the `triggered` signal signature
    - _Requirements: 3.4, 3.7, 3.8, 5.1, 5.2_

  - [ ] 4.5 Refactor `scripts/level_system/sublevel_exit_trigger.gd` to extend `PlayerTrigger`
    - Change base class, keep `class_name SublevelExitTrigger`
    - Remove the local body-detection code
    - Implement `_on_player_entered(_body)` that calls `LevelManager.complete_sublevel()`
    - _Requirements: 3.5, 5.1, 5.2_

  - [ ] 4.6 Refactor `scripts/level_system/checkpoint_marker.gd` to extend `PlayerTrigger`
    - Change base class, keep `class_name CheckpointMarker`
    - Call `super._ready()` from the local `_ready`, then run existing sprite setup
    - Implement `_on_player_entered(_body)` that calls `activate()` when `is_active` is false
    - Preserve `is_active`, `activate()`, and the `marker_activated` signal
    - _Requirements: 3.6, 3.7, 3.8, 5.1, 5.2_

- [ ] 5. LOW — Refactor `KillZone` to delegate to `LevelManager`
  - [ ] 5.1 Rewrite `scripts/kill_zone.gd` handler to delegate respawn
    - Keep `class_name KillZone` and `@export var respawn_position: Vector2` (unused after refactor)
    - On player entry, call `LevelManager.handle_player_death()`
    - Guard for missing `LevelManager` autoload: `push_error` and return
    - Remove `_respawn_player`, `_get_last_checkpoint`, and `_find_checkpoints`
    - Do not mutate `player.global_position` or `player.velocity`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2_

  - [ ]* 5.2 Write unit tests for `KillZone` delegation
    - Create `tests/kill_zone_test.gd`
    - Cover: player entry invokes `LevelManager.handle_player_death()` exactly once (via a stand-in autoload or spy)
    - Cover: non-player bodies do not invoke the delegate
    - Cover: KillZone does not mutate the player's `global_position` or `velocity` directly
    - Cover: absence of `LevelManager` results in `push_error` and no crash
    - _Requirements: 4.1, 4.2, 4.3, 6.4_

- [ ] 6. Backward compatibility — `floor_1.tscn` smoke test
  - [ ] 6.1 Add `floor_1.tscn` load-and-instantiate smoke test
    - Create `tests/floor_1_smoke_test.gd`
    - Use GdUnit4 to load `res://scenes/floor_1.tscn` (adjust path to actual location) via `load()` and instantiate; assert no null result and no missing-script/property/signal errors
    - Free the instantiated scene at test end to keep the runner clean
    - _Requirements: 5.1, 5.2, 5.3_

  - [ ]* 6.2 Add scripted playthrough integration test for `floor_1`
    - Extend `tests/floor_1_smoke_test.gd` (or add a companion file) with a short scripted scenario
    - Cover: horizontal movement, jump, stomp bounce on `EnemyBasic`, checkpoint activation, sublevel transition, and kill zone respawn all produce the same observable outcomes as before the refactor
    - _Requirements: 5.4_

- [ ] 7. Final checkpoint — full test suite green
  - Ensure all tests pass, ask the user if questions arise.
  - Run the GdUnit4 suite via the project's configured runner and confirm the four new test files (`base_enemy_test.gd`, `modifier_stack_test.gd`, `player_trigger_test.gd`, `kill_zone_test.gd`) report all tests passing
  - _Requirements: 6.5_

## Notes

- Tasks marked with `*` are optional test tasks and can be skipped for a faster MVP path. Core implementation tasks (1.1, 1.2, 2.1, 2.7, 4.1, 4.4, 4.5, 4.6, 5.1, 6.1) are required.
- Each task references specific granular acceptance criteria from `requirements.md` for traceability.
- Property tests annotate their property number from `design.md` and the requirements clause they validate.
- No `.tscn` files are edited during this refactor. All `class_name` identifiers, exported fields, and signals are preserved so `floor_1.tscn` continues to load and run unchanged (Requirement 5).
- The `EnemyBasic` scene (`enemy_basic.tscn`) needs no edits because `hp` is inherited from `BaseEnemy` and resolves against the same script path.
- Test files live under `tests/` following the existing project convention. Adjust the `floor_1.tscn` path in task 6.1 if the scene lives under a different subfolder.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "4.1"] },
    { "id": 1, "tasks": ["1.2", "2.7", "4.4", "4.5", "4.6", "5.1", "1.3", "2.2", "4.2"] },
    { "id": 2, "tasks": ["1.4", "2.3", "4.3", "2.8", "5.2", "6.1"] },
    { "id": 3, "tasks": ["2.4", "6.2"] },
    { "id": 4, "tasks": ["2.5"] },
    { "id": 5, "tasks": ["2.6"] }
  ]
}
```