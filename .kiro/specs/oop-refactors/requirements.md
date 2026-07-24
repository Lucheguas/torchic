# Requirements Document

## Introduction

This feature refactors four areas of the Torchic Godot 4.7 GDScript codebase to reduce duplication and clarify responsibilities using object-oriented composition and inheritance. Four artifacts are produced: a `PlayerTrigger` base class for player-detecting `Area2D` triggers, a `BaseEnemy` base class that centralizes enemy hit-point and stomp-defeat logic, a delegation change in `KillZone` so it routes player death through `LevelManager`, and a `ModifierStack` object owned by `MovementController` that encapsulates equipment and level modifiers.

The refactor MUST remain backward-compatible with the existing `floor_1.tscn` scene and any scene that references the affected scripts. All new classes MUST be covered by GdUnit4 unit tests.

Priority ordering:
- HIGH: `BaseEnemy`, `ModifierStack`
- MEDIUM: `PlayerTrigger`
- LOW: `KillZone` delegation

## Glossary

- **PlayerTrigger**: New base class extending `Area2D` that detects a `CharacterBody2D` in the `player` group, fires a one-shot activation, and disconnects `body_entered` after first fire. Parent of `TransitionTrigger`, `SublevelExitTrigger`, and `CheckpointMarker`.
- **BaseEnemy**: New base class extending `CharacterBody2D` that owns an integer `hp` field, exposes `take_stomp_damage(amount)` to subtract HP, and calls `queue_free()` when `hp <= 0`. Parent of `EnemyBasic`.
- **KillZone**: Existing `Area2D` script that reacts to the player entering a hazard area. After refactor, KillZone delegates respawn behavior to `LevelManager.handle_player_death()`.
- **ModifierStack**: New plain `RefCounted` object that stores speed multiplier, speed modifier, jump height bonus, double-jump flag, and stomp bounce multiplier. Owned by `MovementController` via composition (member field, not inheritance).
- **MovementController**: Existing `CharacterBody2D` script for the player. After refactor, it delegates modifier storage and clamping to a `ModifierStack` instance.
- **LevelManager**: Existing autoload that owns `handle_player_death()` and checkpoint respawn logic.
- **GdUnit4**: The unit test framework already configured in the project (`.gdunit4.cfg`).
- **Backward_Compatible**: A change is backward compatible when `floor_1.tscn` opens, runs, and behaves identically to the pre-refactor build without editing the `.tscn` file.
- **one_shot**: A trigger activation mode where the trigger fires at most once per scene lifetime and disconnects its `body_entered` signal after the first fire.

## Requirements

### Requirement 1: BaseEnemy Base Class

**User Story:** As a gameplay programmer, I want a shared `BaseEnemy` class that owns hit points and stomp-defeat logic, so that new enemy types reuse the same damage and death flow without copying code.

#### Acceptance Criteria

1. THE BaseEnemy SHALL extend `CharacterBody2D` and declare an exported integer field `hp` with a default value of 1.
2. THE BaseEnemy SHALL expose a `take_stomp_damage(amount: int)` method that subtracts `amount` from `hp`.
3. WHEN `take_stomp_damage` reduces `hp` to a value less than or equal to 0, THE BaseEnemy SHALL invoke `queue_free()` on itself.
4. THE EnemyBasic SHALL extend BaseEnemy and SHALL delegate its stomp-defeat handling to `BaseEnemy.take_stomp_damage(1)` instead of calling `queue_free()` directly.
5. WHEN the player stomps `EnemyBasic` with a default `hp` of 1, THE EnemyBasic SHALL be removed from the scene tree on the next frame.
6. THE EnemyBasic SHALL retain its existing patrol movement, gravity, and stomp-area detection behavior after the refactor.

### Requirement 2: ModifierStack Composition

**User Story:** As a gameplay programmer, I want equipment and level modifiers stored in a dedicated `ModifierStack` object owned by `MovementController`, so that modifier logic can be tested in isolation and reused by other controllers.

#### Acceptance Criteria

1. THE ModifierStack SHALL extend `RefCounted` and SHALL store the following fields: `base_speed: float`, `speed_modifier: float`, `jump_height_bonus: float`, `double_jump_enabled: bool`, `stomp_bounce_multiplier: float`.
2. THE ModifierStack SHALL expose setter methods `set_base_speed(value)`, `set_speed_modifier(value)`, `set_jump_height_bonus(value)`, `set_double_jump_enabled(value)`, and `set_stomp_bounce_multiplier(value)`.
3. WHEN `set_base_speed` is called with any float, THE ModifierStack SHALL clamp the stored value to the range [1.0, 1.7].
4. WHEN `set_speed_modifier` is called with any float, THE ModifierStack SHALL clamp the stored value to the range [0.0, 0.5].
5. WHEN `set_jump_height_bonus` is called with any float, THE ModifierStack SHALL clamp the stored value to the range [0.0, 1.0].
6. WHEN `set_stomp_bounce_multiplier` is called with any float, THE ModifierStack SHALL clamp the stored value to the range [1.0, 2.0].
7. THE MovementController SHALL own a single ModifierStack instance as a member field and SHALL construct the instance during `_ready` or field initialization.
8. WHEN the caller invokes `MovementController.set_base_speed`, `set_speed_modifier`, `set_jump_height_bonus`, `set_double_jump_enabled`, or `set_stomp_bounce_multiplier`, THE MovementController SHALL forward the call to the ModifierStack instance.
9. THE MovementController SHALL read modifier values from the ModifierStack instance when computing effective speed, jump velocity, and stomp bounce.
10. THE public setter signatures on MovementController SHALL remain unchanged so that callers such as `LevelManager` and equipment systems continue to compile without edits.

### Requirement 3: PlayerTrigger Base Class

**User Story:** As a gameplay programmer, I want a `PlayerTrigger` base class that handles player detection and one-shot activation, so that `TransitionTrigger`, `SublevelExitTrigger`, and `CheckpointMarker` stop duplicating body-detection code.

#### Acceptance Criteria

1. THE PlayerTrigger SHALL extend `Area2D` and SHALL connect its `body_entered` signal to an internal handler during `_ready`.
2. WHEN a `CharacterBody2D` in the `player` group enters the trigger area, THE PlayerTrigger SHALL invoke a virtual method `_on_player_entered(body)` that subclasses override.
3. WHEN `_on_player_entered` has been invoked once, THE PlayerTrigger SHALL disconnect its `body_entered` signal so subsequent bodies do not fire the trigger.
4. THE TransitionTrigger SHALL extend PlayerTrigger and SHALL emit its `triggered(trigger)` signal from within its `_on_player_entered` override.
5. THE SublevelExitTrigger SHALL extend PlayerTrigger and SHALL call `LevelManager.complete_sublevel()` from within its `_on_player_entered` override.
6. THE CheckpointMarker SHALL extend PlayerTrigger and SHALL call its `activate()` method from within its `_on_player_entered` override when `is_active` is false.
7. THE existing exported fields on TransitionTrigger (`target_type`, `sublevel_config`, `transition_visual`), SublevelExitTrigger, and CheckpointMarker (`is_active`) SHALL be preserved with the same names and types.
8. THE existing `triggered` signal on TransitionTrigger and `marker_activated` signal on CheckpointMarker SHALL be preserved with the same names and parameter signatures.

### Requirement 4: KillZone Delegation to LevelManager

**User Story:** As a gameplay programmer, I want `KillZone` to delegate respawn to `LevelManager.handle_player_death()`, so that checkpoint restoration, input gating, and progress state stay consistent with other death flows.

#### Acceptance Criteria

1. WHEN a `CharacterBody2D` in the `player` group enters a KillZone, THE KillZone SHALL call `LevelManager.handle_player_death()`.
2. THE KillZone SHALL NOT read `CheckpointMarker` positions directly after the refactor, and SHALL NOT set `player.global_position` or `player.velocity` directly.
3. IF the `LevelManager` autoload is not available at runtime, THEN THE KillZone SHALL log an error via `push_error` and SHALL take no further respawn action.
4. THE existing exported `respawn_position` field on KillZone SHALL be preserved to keep the `floor_1.tscn` scene loadable without edits, even though the field is no longer read.

### Requirement 5: Backward Compatibility with floor_1.tscn

**User Story:** As a project maintainer, I want the existing `floor_1.tscn` scene to run unchanged after the refactor, so that no scene files need to be re-saved and version control diffs stay minimal.

#### Acceptance Criteria

1. THE refactor SHALL preserve the `class_name` identifiers `TransitionTrigger`, `SublevelExitTrigger`, `CheckpointMarker`, `KillZone`, `EnemyBasic`, and `MovementController`.
2. THE refactor SHALL preserve the file paths and `.uid` files for `scripts/kill_zone.gd`, `scripts/enemy_basic.gd`, `scripts/movement_controller.gd`, `scripts/level_system/transition_trigger.gd`, `scripts/level_system/sublevel_exit_trigger.gd`, and `scripts/level_system/checkpoint_marker.gd`.
3. WHEN `floor_1.tscn` is loaded after the refactor, THE Godot editor SHALL open the scene without reporting missing script, missing signal, or missing property errors.
4. WHEN `floor_1.tscn` is played after the refactor, THE player character SHALL respond to horizontal movement, jump, double jump when enabled, stomp bounce, checkpoint activation, sublevel transitions, and kill zone respawn with the same observable outcomes as before the refactor.

### Requirement 6: GdUnit4 Test Coverage for New Classes

**User Story:** As a project maintainer, I want each new base class and composition object covered by GdUnit4 unit tests, so that regressions in the refactor are caught in CI.

#### Acceptance Criteria

1. THE test suite SHALL include a GdUnit4 test file for BaseEnemy covering HP subtraction, death on `hp <= 0`, and preservation of `hp` above zero after a non-lethal hit.
2. THE test suite SHALL include a GdUnit4 test file for ModifierStack covering clamping of `base_speed` to [1.0, 1.7], `speed_modifier` to [0.0, 0.5], `jump_height_bonus` to [0.0, 1.0], and `stomp_bounce_multiplier` to [1.0, 2.0], plus toggling of `double_jump_enabled`.
3. THE test suite SHALL include a GdUnit4 test file for PlayerTrigger covering one-shot activation: a first player body fires `_on_player_entered`, and a second body entering after the first does not fire it.
4. THE test suite SHALL include a GdUnit4 test file for KillZone covering that entering the area invokes `LevelManager.handle_player_death()` via a mock or stand-in, and that the KillZone does not mutate the player's position directly.
5. WHEN the GdUnit4 test suite is executed via the project's configured runner, THE test suite SHALL report all tests in the four new files as passing.
