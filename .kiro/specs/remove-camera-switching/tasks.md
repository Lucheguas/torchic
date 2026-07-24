# Implementation Plan: Remove Camera Switching

## Overview

This plan removes the per-sub-level camera perspective switching from the Godot 4 "torchic"
project. Work proceeds incrementally: first the `LevelManager` autoload is decoupled from the
`CameraController` (while preserving the camera-provisioning logic on floor load), then the
`SubLevelType`/`sublevel_type` data is removed, then the `CameraController` node and script are
deleted, then scenes/resources and documentation are cleaned, and finally a static check
confirms no dangling references remain.

Ordering note: the `LevelManager` script is edited first so nothing references the deleted
symbols before they are removed, avoiding runtime/missing-dependency errors.

Implementation language: **GDScript (Godot 4)**. Tests use **gdUnit4** (config already present
at `.gdunit4.cfg`); the project has no existing test suite, so test tasks create new files and
are marked optional.

## Tasks

- [x] 1. Decouple LevelManager from the camera controller
  - [x] 1.1 Remove CameraController wiring from `scripts/level_system/level_manager.gd`
    - Remove the `@onready var camera_controller: Node = $CameraController` declaration
    - Remove the `camera_controller.camera_ready.connect(_on_camera_ready)` line in `_ready()`
    - Remove the `_on_camera_ready(_sublevel_type)` handler
    - Update the class doc comment that mentions "camera changes"
    - _Requirements: 2.1, 2.2, 2.6_

  - [x] 1.2 Remove perspective calls and keep camera provisioning in `level_manager.gd`
    - In `_on_enter_sublevel_transition_finished()`: remove `var cam_type := current_sublevel.sublevel_type` and `camera_controller.apply_sublevel_perspective(cam_type)`; keep scene instantiation, `PLAYING_SUBLEVEL` state, input re-enable, and `sublevel_entered.emit(...)`
    - In `_on_exit_sublevel_transition_finished()`: remove `camera_controller.reset_to_main_level()`; keep unload, visibility restore, checkpoint exit, `PLAYING_MAIN_LEVEL` state, and `sublevel_completed.emit(...)`
    - In `_on_scene_loaded()`: remove both `camera_controller.setup_camera(...)` calls; keep the "find/create player `Camera2D` and `make_current()`" logic; on failure to locate/create the camera, `push_error` with the cause and leave existing Player nodes intact
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 3.1, 3.3, 3.4_

  - [ ]* 1.3 Write property tests for camera transform invariance
    - **Property 1: Camera invariance on entry** and **Property 2: Camera invariance on exit** and **Property 3: Full-cycle invariance**
    - Parameterized over sub-level scenarios; assert `zoom == Vector2(1,1)`, `offset == Vector2(0,0)`, `rotation == 0.0` are unchanged before/after enter, exit, and a full enter→exit cycle
    - **Validates: Requirements 2.3, 2.4, 3.2**

  - [ ]* 1.4 Write property test for camera availability after floor load
    - **Property 4: Camera availability**
    - Assert that after a floor load with a player present, the player has exactly one `Camera2D` and it is `current` — both when a camera pre-exists and when it must be created
    - **Validates: Requirements 2.5, 3.1, 3.3**

- [ ] 2. Remove SubLevelType and sublevel_type from SubLevelConfig
  - [ ] 2.1 Strip the camera-bound type from `scripts/level_system/data/sublevel_config.gd`
    - Remove the `enum SubLevelType { ... }` declaration
    - Remove the `@export var sublevel_type: SubLevelType = SubLevelType.CHASE` export
    - Update the stale header comment referencing `CameraController.SubLevelType`
    - Keep `sublevel_id`, `scene_path`, `transition_type`, `has_time_limit`, `time_limit_seconds` and the `validate(parent_floor_id)` logic unchanged
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ]* 2.2 Write property test for SubLevelConfig.validate
    - **Property 6: Config integrity** (validate behavior unchanged after removing `sublevel_type`)
    - Assert: valid config returns empty array; empty `sublevel_id` reports floor id; empty/nonexistent `scene_path` reports floor id, sublevel id, and condition; `has_time_limit` true with `time_limit_seconds <= 0` reports invalid time limit
    - **Validates: Requirements 4.4, 4.5, 4.6, 4.7**

- [ ] 3. Checkpoint - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Remove the CameraController component
  - [ ] 4.1 Remove the CameraController node from `scenes/level_system/level_manager.tscn`
    - Delete the `[node name="CameraController" type="Node" parent="."]` entry
    - Delete the `[ext_resource ... path="res://scripts/level_system/camera_controller.gd" id="3"]` declaration
    - Update `load_steps` in the scene header accordingly
    - _Requirements: 1.3, 1.4, 1.5_

  - [ ] 4.2 Delete the camera controller script files
    - Delete `scripts/level_system/camera_controller.gd`
    - Delete `scripts/level_system/camera_controller.gd.uid`
    - _Requirements: 1.1, 1.2_

- [ ] 5. Clean scenes and resources of sublevel_type assignments
  - [ ] 5.1 Remove `sublevel_type` from `scenes/levels/floor_1.tscn`
    - Delete the `sublevel_type = 0` assignment in the `SubLevelConfig` sub-resource
    - Preserve `sublevel_id`, `scene_path`, `transition_type`, `has_time_limit`, `time_limit_seconds`
    - _Requirements: 5.1, 5.3, 5.4_

  - [ ] 5.2 Remove `sublevel_type` from `resources/level_registry.tres`
    - Delete every `sublevel_type = N` assignment across all `SubLevelConfig` sub-resources
    - Preserve all other `SubLevelConfig` fields unchanged
    - _Requirements: 5.2, 5.3, 5.4_

- [ ] 6. Update project documentation
  - [ ] 6.1 Update `PROYECTO_COMPLETO.md`
    - Remove `CameraController` / `camera_controller.gd` entries (file tree, script section, node tree)
    - Remove the `sublevel_type` row from the SubLevelConfig field table
    - Describe the Follow_Camera as a `Camera2D` child of the Player with zoom `Vector2(1,1)`, offset `Vector2(0,0)`, rotation `0.0` that follows the player without perspective changes
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ] 6.2 Update `Game Design Document GDD - Platformer Core System v2.md` and `mapa_1_tutorial_spec.md`
    - Remove descriptions of the camera-switching mechanic and the `CameraController` component
    - Remove `sublevel_type` / `SubLevelType` from any SubLevelConfig field descriptions
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 7. Verify project integrity
  - [ ]* 7.1 Write a static check test for removed symbols
    - **Property 5: No dangling references**
    - Assert no references to `CameraController`, `camera_controller`, `SubLevelType`, `sublevel_type`, `apply_sublevel_perspective`, `reset_to_main_level`, `setup_camera`, `camera_ready`, `camera_reset`, `CAMERA_CONFIGS`, or `get_perspective_for_type` remain under `scripts/` and `scenes/`
    - **Validates: Requirements 1.1, 1.3, 1.4, 2.1, 2.2, 2.6, 4.1, 4.2, 7.1**

- [ ] 8. Final checkpoint - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional (test tasks) and can be skipped for a faster MVP.
- Each task references specific requirements for traceability.
- The `LevelManager` script (`level_manager.gd`) is edited across tasks 1.1 and 1.2, which are
  sequenced so they do not run in parallel.
- Property tests use gdUnit4 parameterized tests to iterate camera invariance across sub-level
  scenarios; the project has no prior test suite, so these files are created fresh.
- Checkpoints ensure incremental validation before continuing.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1", "4.1", "4.2", "6.1", "6.2"] },
    { "id": 3, "tasks": ["2.2", "5.1", "5.2"] },
    { "id": 4, "tasks": ["1.3", "1.4", "7.1"] }
  ]
}
```
