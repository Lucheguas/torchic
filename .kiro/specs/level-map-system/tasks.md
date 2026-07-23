# Implementation Plan: Level Map System

## Overview

Implement the complete level map system for Torchic: a Level_Manager autoload singleton that orchestrates 15 floors of progression with checkpoints, sub-levels with camera changes, entre-nivel shop zones, async scene loading, and persistent save data. Built incrementally from data resources → subsystems → manager → scene nodes → integration.

## Tasks

- [x] 1. Create custom Resource data models
  - [x] 1.1 Create SubLevelConfig resource script
    - Create `scripts/level_system/data/sublevel_config.gd` with `class_name SubLevelConfig` extending `Resource`
    - Define exports: `sublevel_id: String`, `sublevel_type: CameraController.SubLevelType`, `scene_path: String`, `transition_type: TransitionAnimator.TransitionType`, `has_time_limit: bool`, `time_limit_seconds: float`
    - Implement `validate(parent_floor_id: int) -> Array[String]` checking empty IDs, missing scene paths, and invalid time limits
    - _Requirements: 12.1, 12.2_

  - [x] 1.2 Create LevelConfigData resource script
    - Create `scripts/level_system/data/level_config_data.gd` with `class_name LevelConfigData` extending `Resource`
    - Define exports: `floor_id: int`, `phase: Phase`, `scene_path: String`, `sublevels: Array[SubLevelConfig]`, `boss_type: BossType`, `entre_nivel_scene_path: String`, `map_length_px: float`
    - Define enums: `BossType { MINI, MAJOR }`, `Phase { FOREST, CAVE, LABORATORY }`
    - Implement `get_phase_for_floor(floor_id: int) -> Phase` with Forest 1-5, Cave 6-10, Laboratory 11-15
    - Implement `is_major_boss_floor() -> bool` returning true for floors 5, 10, 15
    - Implement `validate() -> Array[String]` checking floor_id > 0, non-empty scene_path, ResourceLoader.exists(), sublevel validation, and boss type consistency
    - _Requirements: 1.4, 12.1, 12.2, 12.4_

  - [x] 1.3 Create LevelRegistry resource script
    - Create `scripts/level_system/data/level_registry.gd` with `class_name LevelRegistry` extending `Resource`
    - Define export: `levels: Array[LevelConfigData]`
    - Implement `get_level_config(floor_id: int) -> LevelConfigData` searching by floor_id
    - Implement `get_total_floors() -> int` returning array size
    - Implement `validate() -> Array[String]` iterating all level configs and collecting errors
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 1.4 Create FloorProgressData resource script with save/load
    - Create `scripts/level_system/data/floor_progress_data.gd` with `class_name FloorProgressData` extending `Resource`
    - Define exports: `highest_floor_reached: int`, `current_floor: int`, `completed_sublevels: Dictionary`, `active_checkpoints: Dictionary`, `player_hp: int`, `player_tokens: int`, `player_exp: int`, `player_level: int`, `player_equipment: Array[String]`
    - Define `const SAVE_PATH: String = "user://floor_progress.tres"`
    - Implement `update_floor_completed(floor_id: int)` updating highest_floor_reached and current_floor
    - Implement `mark_sublevel_completed(floor_id: int, sublevel_id: String)` appending to completed_sublevels dictionary
    - Implement `save_to_disk() -> Error` using ResourceSaver.save()
    - Implement `static func load_from_disk() -> FloorProgressData` with fallback to new instance on corruption
    - Implement `capture_player_state(player: CharacterBody2D)` and `restore_player_state(player: CharacterBody2D)`
    - _Requirements: 1.5, 11.1, 11.2, 11.3, 11.4, 11.5_

  - [ ]* 1.5 Write property tests for data models
    - **Property 2: Boss Type Determination** — Generate all 15 floor IDs, verify MAJOR only for {5, 10, 15}
    - **Property 12: Floor Progress Data Accuracy** — Generate random sequences of floor completions, verify highest_floor_reached == max and current_floor == min(max+1, 15)
    - **Property 13: Save/Load Round-Trip** — Generate random FloorProgressData instances, save then load, verify all fields are equal
    - **Property 14: Configuration Validation** — Generate valid and invalid LevelConfigData entries, verify validation correctness
    - Create `test/level_system/test_data_properties.gd` using GUT with manual randomization (100+ iterations)
    - **Validates: Requirements 1.4, 1.5, 11.1, 11.3, 11.4, 11.5, 12.2, 12.4**

- [x] 2. Checkpoint - Data models verified
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Implement subsystem components
  - [x] 3.1 Implement Scene_Loader component
    - Create `scripts/level_system/scene_loader.gd` with `class_name SceneLoader` extending `Node`
    - Define signals: `scene_loaded(scene: PackedScene)`, `load_progress_updated(progress: float)`, `load_failed(path: String, error: String)`
    - Define state: `_loading_path: String`, `_is_loading: bool`, `_retry_count: int`, `MAX_RETRIES: int = 1`
    - Implement `request_load(scene_path: String)` using `ResourceLoader.load_threaded_request()` with guard against duplicate requests
    - Implement `_process(delta)` polling `ResourceLoader.load_threaded_get_status()` and emitting progress/completion/failure signals
    - Implement `preload_scene(scene_path: String)` for fire-and-forget preloading during Entre_Nivel
    - Implement `unload_scene(scene_root: Node)` calling `queue_free()` safely
    - Implement `_handle_load_error(error_msg: String)` with retry logic (max 1 retry)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 3.2 Implement Checkpoint_System component
    - Create `scripts/level_system/checkpoint_system.gd` with `class_name CheckpointSystem` extending `Node`
    - Define signals: `checkpoint_activated(checkpoint_id: int, position: Vector2)`, `respawn_requested(position: Vector2)`
    - Define state: `active_checkpoint_position`, `has_active_checkpoint`, `level_start_position`, `sublevel_start_position`, `is_in_sublevel`, `checkpoint_markers: Array[CheckpointMarker]`, `_map_start_x`, `_map_end_x`, `_checkpoint_1_active`, `_checkpoint_2_active`
    - Implement `initialize_for_level(start_pos, map_start_x, map_end_x)` resetting all state
    - Implement `calculate_progress(player_x: float) -> float` with clamp to [0.0, 1.0]
    - Implement `update_checkpoints(player_x: float)` activating checkpoints at 33% and 66% thresholds
    - Implement `get_respawn_position() -> Vector2` with sublevel/checkpoint/start fallback chain
    - Implement `enter_sublevel(entry_position, sublevel_start)` and `exit_sublevel(return_position)`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 3.3 Implement Camera_Controller component
    - Create `scripts/level_system/camera_controller.gd` with `class_name CameraController` extending `Node`
    - Define signals: `camera_ready(sublevel_type: SubLevelType)`, `camera_reset()`
    - Define enum: `SubLevelType { CHASE, INFILTRATION, PRECISION_AIMING, ENVIRONMENTAL_PUZZLE }`
    - Define `CAMERA_CONFIGS: Dictionary` with zoom, offset, and rotation presets per sublevel type (CHASE: 1.5x zoom, INFILTRATION: 1.2x, PRECISION_AIMING: 0.7x, ENVIRONMENTAL_PUZZLE: 0.5x)
    - Implement `setup_camera(camera: Camera2D)` storing reference
    - Implement `apply_sublevel_perspective(type: SubLevelType)` setting camera properties from config
    - Implement `reset_to_main_level()` restoring default camera values (1.0x zoom, zero offset/rotation)
    - Implement `get_perspective_for_type(type: SubLevelType) -> Dictionary`
    - _Requirements: 4.3, 5.1, 6.1, 7.1, 8.1_

  - [x] 3.4 Implement Transition_Animator component
    - Create `scripts/level_system/transition_animator.gd` with `class_name TransitionAnimator` extending `Node`
    - Define signals: `transition_started(type: TransitionType)`, `transition_finished()`
    - Define enum: `TransitionType { DOOR, PIPE, DATA_PORTAL }`
    - Define `const TRANSITION_DURATION: float = 1.5`
    - Define state: `_is_transitioning: bool`, `_tween: Tween`
    - Implement `play_enter_transition(type: TransitionType)` using Tween with 1.5s duration and cubic ease
    - Implement `play_exit_transition(type: TransitionType)` for return transitions
    - Implement `is_transitioning() -> bool`
    - Implement `_on_transition_complete()` emitting `transition_finished` signal
    - _Requirements: 4.1, 4.2, 4.5_

  - [ ]* 3.5 Write property tests for subsystem logic
    - **Property 3: Progress Calculation** — Generate random player_x, start_x, end_x, verify result equals clamp((player_x - start_x) / (end_x - start_x), 0.0, 1.0)
    - **Property 4: Checkpoint Activation by Progress Threshold** — Generate random progress sequences, verify checkpoints activate at >=0.33 and >=0.66 and never deactivate
    - **Property 5: Respawn Position Selection** — Generate random checkpoint activation states + death events, verify correct respawn position
    - **Property 8: Camera-SubLevel Type Correspondence** — For each SubLevelType, verify camera config matches CAMERA_CONFIGS preset exactly
    - **Property 15: Load Retry on Failure** — Simulate load failures, verify max 2 attempts total
    - Create `test/level_system/test_subsystem_properties.gd` using GUT (100+ iterations)
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 4.3, 5.1, 6.1, 7.1, 8.1, 10.5**

- [x] 4. Checkpoint - Subsystems verified
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement Level_Manager autoload
  - [x] 5.1 Create Level_Manager script with state machine and signals
    - Create `scripts/level_system/level_manager.gd` with `class_name LevelManager` extending `Node`
    - Define all signals: `floor_started`, `floor_completed`, `sublevel_entered`, `sublevel_completed`, `entre_nivel_entered`, `entre_nivel_exited`, `player_respawned`, `game_state_saved`
    - Define `GameFlowState` enum: LOADING, PLAYING_MAIN_LEVEL, TRANSITION_TO_SUBLEVEL, PLAYING_SUBLEVEL, TRANSITION_TO_MAIN, TRANSITION_TO_ENTRE_NIVEL, ENTRE_NIVEL, RESPAWNING
    - Define state variables: `current_state`, `current_floor_id`, `current_sublevel`, `player_ref`
    - Set up `@onready` references to child nodes: `checkpoint_system`, `camera_controller`, `transition_animator`, `scene_loader`
    - Load `level_registry` and `floor_progress` resources in `_ready()`
    - _Requirements: 1.1, 1.2, 1.5_

  - [x] 5.2 Implement floor loading and completion flow
    - Implement `start_game(from_save: bool)` loading FloorProgressData and calling `load_floor()`
    - Implement `load_floor(floor_id: int)` transitioning state to LOADING, requesting scene via scene_loader, connecting `scene_loaded` signal
    - Implement `_on_scene_loaded(packed_scene: PackedScene)` removing old scene, instantiating new one, finding player reference, initializing checkpoint_system, emitting `floor_started`
    - Implement `complete_floor()` saving progress, transitioning to TRANSITION_TO_ENTRE_NIVEL, triggering transition animation, then loading entre_nivel scene
    - Implement `exit_entre_nivel()` transitioning from ENTRE_NIVEL to LOADING, calling `load_floor(current_floor_id + 1)` with preload optimization
    - Implement `get_current_floor_config() -> LevelConfigData` from registry
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 9.1, 9.4, 9.5, 11.1, 11.3_

  - [x] 5.3 Implement sublevel transitions and death handling
    - Implement `enter_sublevel(trigger: TransitionTrigger)` → disable input → play transition → load sublevel scene → apply camera perspective → enable input → emit signal
    - Implement `complete_sublevel()` → disable input → play exit transition → unload sublevel → reset camera → restore main level → enable input → mark completed in FloorProgressData
    - Implement `handle_player_death()` → set RESPAWNING state → get respawn position from checkpoint_system → reposition player → restore state → emit `player_respawned`
    - Implement `set_player_input_enabled(enabled: bool)` disabling/enabling process_input and physics_process on player_ref
    - Implement `save_progress()` calling `floor_progress.save_to_disk()` and emitting `game_state_saved`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 9.5, 11.2, 11.4_

  - [x] 5.4 Register Level_Manager as Autoload in project.godot
    - Add `[autoload]` section entry: `LevelManager="*res://scripts/level_system/level_manager.gd"`
    - Create a placeholder Level_Manager scene (`scenes/level_system/level_manager.tscn`) with CheckpointSystem, CameraController, TransitionAnimator, and SceneLoader as child nodes
    - Or configure Level_Manager to add child nodes programmatically in `_ready()` if preferred
    - Verify the autoload is accessible via `LevelManager` singleton reference
    - _Requirements: 1.1 (autoload singleton architecture)_

  - [ ]* 5.5 Write property tests for Level_Manager state logic
    - **Property 1: Level Sequencing** — For any floor N in [1,14], completing floor N results in entre_nivel before floor N+1
    - **Property 6: Sublevel Death Isolation** — Simulate death in sublevel, verify FloorProgressData unchanged
    - **Property 7: Input Disabled During Transition** — Verify player input is disabled while is_transitioning == true
    - **Property 11: Player State Preservation** — Generate random player states, simulate transition, verify state preserved
    - Create `test/level_system/test_level_manager_properties.gd` using GUT (100+ iterations)
    - **Validates: Requirements 1.3, 3.3, 3.4, 4.2, 9.5, 11.2**

- [x] 6. Checkpoint - Level_Manager core verified
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Create scene nodes (CheckpointMarker and TransitionTrigger)
  - [x] 7.1 Create CheckpointMarker Area2D scene and script
    - Create `scripts/level_system/checkpoint_marker.gd` with `class_name CheckpointMarker` extending `Area2D`
    - Define signal: `marker_activated()`
    - Define state: `is_active: bool = false`
    - Define `@onready` references: `flag_sprite: Sprite2D = $CheckpointFlag`, `animation_player: AnimationPlayer = $AnimationPlayer`
    - Define constants: `INACTIVE_COLOR := Color(0.5, 0.5, 0.5, 1.0)`, `ACTIVE_COLOR := Color(0.2, 0.9, 0.2, 1.0)`
    - In `_ready()`: set flag_sprite modulate to INACTIVE_COLOR, connect `body_entered` signal
    - Implement `activate()` setting `is_active = true`, changing modulate to ACTIVE_COLOR, playing "wave" animation, emitting signal
    - Implement `_on_body_entered(body)` activating if body is CharacterBody2D and not already active
    - Create reusable scene `scenes/level_system/checkpoint_marker.tscn` with Area2D root, CollisionShape2D, Sprite2D (CheckpointFlag), and AnimationPlayer with "wave" animation
    - _Requirements: 2.6, 2.7, 2.8, 2.9_

  - [x] 7.2 Create TransitionTrigger Area2D scene and script
    - Create `scripts/level_system/transition_trigger.gd` with `class_name TransitionTrigger` extending `Area2D`
    - Define signal: `triggered(trigger: TransitionTrigger)`
    - Define exports: `target_type: TargetType`, `sublevel_config: SubLevelConfig`, `transition_visual: TransitionAnimator.TransitionType`
    - Define enum: `TargetType { SUBLEVEL, ENTRE_NIVEL, NEXT_FLOOR }`
    - In `_ready()`: connect `body_entered` signal
    - Implement `_on_body_entered(body)` emitting `triggered` if body is CharacterBody2D (with double-trigger prevention by disconnecting signal after first activation)
    - Create reusable scene `scenes/level_system/transition_trigger.tscn` with Area2D root and CollisionShape2D
    - _Requirements: 4.1, 4.5_

  - [ ]* 7.3 Write unit tests for scene node scripts
    - Test CheckpointMarker activates on CharacterBody2D entry and ignores other bodies
    - Test CheckpointMarker only activates once (idempotent)
    - Test CheckpointMarker changes flag color from grey to green
    - Test TransitionTrigger emits signal on CharacterBody2D entry
    - Test TransitionTrigger double-trigger prevention (only fires once)
    - Create `test/level_system/test_scene_nodes.gd` using GUT
    - **Validates: Requirements 2.7, 2.8, 4.1**

- [x] 8. Create sample level registry and floor configuration
  - [x] 8.1 Create LevelRegistry resource with placeholder floor configs
    - Create `resources/level_registry.tres` as a LevelRegistry resource
    - Create at minimum floor 1 LevelConfigData with: floor_id=1, phase=FOREST, scene_path to a placeholder scene, one CHASE sublevel config, boss_type=MINI
    - Create floor 5 LevelConfigData with: floor_id=5, phase=FOREST, boss_type=MAJOR, one PRECISION_AIMING sublevel
    - Create placeholder scene files (minimal Node2D scenes) for testing: `scenes/levels/floor_1.tscn`, `scenes/levels/floor_5.tscn`, `scenes/entre_nivel.tscn`
    - Wire Level_Manager `_ready()` to load this registry resource
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 9. Wire Level_Manager signal connections and integration
  - [x] 9.1 Connect all internal signals between subsystems
    - In Level_Manager `_ready()`: connect `scene_loader.scene_loaded` → `_on_scene_loaded`
    - Connect `scene_loader.load_failed` → `_on_load_failed`
    - Connect `checkpoint_system.checkpoint_activated` → `_on_checkpoint_activated`
    - Connect `transition_animator.transition_finished` → `_on_transition_finished`
    - Connect `camera_controller.camera_ready` → `_on_camera_ready`
    - Implement stub handlers for each signal that advance the GameFlowState machine correctly
    - _Requirements: 1.1, 1.2, 1.3, 4.1, 10.3_

  - [x] 9.2 Wire TransitionTrigger signals to Level_Manager in level scenes
    - Add logic in `_on_scene_loaded()` to find all TransitionTrigger nodes in the new scene (using groups or `find_children`)
    - Connect each trigger's `triggered` signal to `Level_Manager.enter_sublevel()`
    - Add logic to find player reference (`get_tree().get_first_node_in_group("player")`)
    - Add logic to find CheckpointMarker nodes and register them with checkpoint_system
    - Ensure player node is in "player" group for detection
    - _Requirements: 4.1, 2.6_

  - [x] 9.3 Implement Entre_Nivel preloading and exit flow
    - In `_on_entre_nivel_loaded()`: emit `entre_nivel_entered`, set state to ENTRE_NIVEL
    - Implement `preload_scene()` call for next floor during Entre_Nivel (call `scene_loader.preload_scene()` with next floor's scene_path)
    - Connect exit confirmation (button/trigger in entre_nivel scene) to `Level_Manager.exit_entre_nivel()`
    - _Requirements: 9.1, 9.4, 10.6_

- [x] 10. Checkpoint - Full integration verified
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Integration and final wiring
  - [x] 11.1 Create a minimal playable test level scene
    - Create `scenes/levels/floor_1.tscn` with: Node2D root, TileMapLayer for ground, Player spawn position marker, 2 CheckpointMarker instances at ~33% and ~66% horizontal positions, 1 TransitionTrigger for a sublevel entry, end-of-level trigger (NEXT_FLOOR type)
    - Create `scenes/levels/sublevel_chase_1.tscn` with: Node2D root, basic platform layout, exit trigger at the end
    - Create `scenes/entre_nivel.tscn` with: Node2D root, basic layout, exit trigger/button
    - Ensure player scene is instanced with "player" group membership
    - _Requirements: 1.2, 2.6, 4.1, 5.1, 9.1_

  - [x] 11.2 Wire Level_Manager startup to main scene
    - Modify `scenes/main.tscn` or game startup to call `LevelManager.start_game()` on game launch
    - Ensure Level_Manager finds camera in the scene tree (or creates one) and passes it to camera_controller via `setup_camera()`
    - Test full flow: game start → floor loads → player spawns → checkpoints work → sublevel entry → transition → sublevel plays → return → floor completion → entre_nivel → next floor
    - _Requirements: 1.1, 1.2, 1.3, 11.5_

  - [ ]* 11.3 Write integration tests for full level flow
    - Test full floor cycle: load floor → checkpoints activate at 33%/66% → complete → entre_nivel → next floor
    - Test sublevel cycle: trigger → transition animation (1.5s) → sublevel active → complete → return
    - Test death/respawn: die at various progress points → correct respawn position
    - Test save/load cycle: complete floors → save → reload → verify correct floor loaded
    - Create `test/level_system/test_integration.gd` using GUT
    - **Validates: Requirements 1.3, 2.2, 2.3, 2.4, 3.3, 4.1, 9.1, 11.4, 11.5**

- [x] 12. Final checkpoint - All tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties using GUT with manual `randf_range()`/`randi_range()` loops (100+ iterations)
- Unit tests validate specific examples and edge cases
- The existing `scripts/player.gd` / `scripts/movement_controller.gd` is NOT modified; the Level_Manager interacts with it via signals and public setters
- Placeholder scenes are minimal Node2D trees for testing; actual level design (tilemaps, enemies, art) is separate work
- Sub-level type-specific gameplay (CHASE auto-forward, PRECISION_AIMING mouse aim, PUZZLE switches) will need additional scripts per sublevel type — this plan covers the framework and one example (CHASE). Full per-type gameplay is future work built on this foundation.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "1.4"] },
    { "id": 2, "tasks": ["1.5"] },
    { "id": 3, "tasks": ["3.1", "3.2", "3.3", "3.4"] },
    { "id": 4, "tasks": ["3.5"] },
    { "id": 5, "tasks": ["5.1"] },
    { "id": 6, "tasks": ["5.2", "5.3", "5.4"] },
    { "id": 7, "tasks": ["5.5", "7.1", "7.2"] },
    { "id": 8, "tasks": ["7.3", "8.1"] },
    { "id": 9, "tasks": ["9.1", "9.2", "9.3"] },
    { "id": 10, "tasks": ["11.1", "11.2"] },
    { "id": 11, "tasks": ["11.3"] }
  ]
}
```
