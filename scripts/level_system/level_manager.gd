extends Node
## Autoload singleton that orchestrates the complete level flow:
## floor loading, sub-level transitions, entre-nivel zones, checkpoints,
## camera changes, and persistent save data.
## Access globally via the "LevelManager" autoload name (no class_name needed).

# --- Signals ---
signal floor_started(floor_id: int)
signal floor_completed(floor_id: int)
signal sublevel_entered(sublevel_config)
signal sublevel_completed(sublevel_config)
signal entre_nivel_entered()
signal entre_nivel_exited()
signal player_respawned(position: Vector2)
signal game_state_saved()

# --- State Machine ---
enum GameFlowState {
	LOADING,
	PLAYING_MAIN_LEVEL,
	TRANSITION_TO_SUBLEVEL,
	PLAYING_SUBLEVEL,
	TRANSITION_TO_MAIN,
	TRANSITION_TO_ENTRE_NIVEL,
	ENTRE_NIVEL,
	RESPAWNING,
}

var current_state: GameFlowState = GameFlowState.LOADING
var current_floor_id: int = 1
var current_sublevel = null  # SubLevelConfig
var player_ref: CharacterBody2D = null
var _current_scene_root: Node = null
var _sublevel_scene_root: Node = null

# --- Child Node References ---
@onready var checkpoint_system: Node = $CheckpointSystem
@onready var camera_controller: Node = $CameraController
@onready var transition_animator: Node = $TransitionAnimator
@onready var scene_loader: Node = $SceneLoader

# --- Resources ---
var level_registry = null  # LevelRegistry
var floor_progress = null  # FloorProgressData


func _ready() -> void:
	# Load level registry resource (may not exist yet during early development)
	var registry_path := "res://resources/level_registry.tres"
	if ResourceLoader.exists(registry_path):
		level_registry = ResourceLoader.load(registry_path)
	else:
		push_warning("LevelManager: level_registry.tres not found at " + registry_path)

	# Load floor progress (creates new instance if no save exists)
	var fpd_script = load("res://scripts/level_system/data/floor_progress_data.gd")
	if fpd_script:
		floor_progress = fpd_script.load_from_disk()
	else:
		push_error("LevelManager: Could not load FloorProgressData script")

	# Connect permanent subsystem signals
	scene_loader.load_failed.connect(_on_load_failed)
	checkpoint_system.checkpoint_activated.connect(_on_checkpoint_activated)
	camera_controller.camera_ready.connect(_on_camera_ready)


# --- Public Methods ---

func start_game(from_save: bool = false) -> void:
	if from_save:
		var fpd_script = load("res://scripts/level_system/data/floor_progress_data.gd")
		floor_progress = fpd_script.load_from_disk()
	current_floor_id = floor_progress.current_floor
	load_floor(current_floor_id)


func load_floor(floor_id: int) -> void:
	current_state = GameFlowState.LOADING
	current_floor_id = floor_id
	var config = get_current_floor_config()
	if config == null:
		push_error("LevelManager: No config found for floor_id %d" % floor_id)
		return
	if not scene_loader.scene_loaded.is_connected(_on_scene_loaded):
		scene_loader.scene_loaded.connect(_on_scene_loaded)
	scene_loader.request_load(config.scene_path)


func complete_floor() -> void:
	floor_progress.update_floor_completed(current_floor_id)
	floor_progress.save_to_disk()
	floor_completed.emit(current_floor_id)
	current_state = GameFlowState.TRANSITION_TO_ENTRE_NIVEL
	var config = get_current_floor_config()
	transition_animator.play_enter_transition(0)  # DOOR = 0
	await transition_animator.transition_finished
	# Load the entre_nivel scene
	var entre_nivel_path: String = config.entre_nivel_scene_path if config else "res://scenes/entre_nivel.tscn"
	if not scene_loader.scene_loaded.is_connected(_on_scene_loaded):
		scene_loader.scene_loaded.connect(_on_scene_loaded)
	scene_loader.request_load(entre_nivel_path)


func enter_sublevel(trigger) -> void:
	if current_state != GameFlowState.PLAYING_MAIN_LEVEL:
		return
	current_state = GameFlowState.TRANSITION_TO_SUBLEVEL
	current_sublevel = trigger.sublevel_config
	set_player_input_enabled(false)
	# Register sublevel entry in checkpoint system
	var sublevel_start_pos := Vector2.ZERO
	checkpoint_system.enter_sublevel(player_ref.global_position, sublevel_start_pos)
	# Play enter transition, then continue on transition_finished
	transition_animator.transition_finished.connect(_on_enter_sublevel_transition_finished, CONNECT_ONE_SHOT)
	transition_animator.play_enter_transition(trigger.transition_visual)


func complete_sublevel() -> void:
	if current_state != GameFlowState.PLAYING_SUBLEVEL:
		return
	current_state = GameFlowState.TRANSITION_TO_MAIN
	set_player_input_enabled(false)
	# Play exit transition, then continue on transition_finished
	var trans_type: int = current_sublevel.transition_type
	transition_animator.transition_finished.connect(_on_exit_sublevel_transition_finished, CONNECT_ONE_SHOT)
	transition_animator.play_exit_transition(trans_type)


func exit_entre_nivel() -> void:
	if current_state != GameFlowState.ENTRE_NIVEL:
		push_warning("LevelManager: exit_entre_nivel called while not in ENTRE_NIVEL state")
		return
	entre_nivel_exited.emit()
	current_state = GameFlowState.LOADING
	var next_floor_id := current_floor_id + 1
	load_floor(next_floor_id)


func handle_player_death() -> void:
	if not player_ref:
		return
	current_state = GameFlowState.RESPAWNING
	set_player_input_enabled(false)
	var respawn_pos: Vector2 = checkpoint_system.get_respawn_position()
	player_ref.global_position = respawn_pos
	player_ref.velocity = Vector2.ZERO
	# Restore player state from floor progress data
	floor_progress.restore_player_state(player_ref)
	set_player_input_enabled(true)
	# Return to the appropriate playing state
	if checkpoint_system.is_in_sublevel:
		current_state = GameFlowState.PLAYING_SUBLEVEL
	else:
		current_state = GameFlowState.PLAYING_MAIN_LEVEL
	player_respawned.emit(respawn_pos)


func save_progress() -> void:
	if floor_progress:
		floor_progress.save_to_disk()
		game_state_saved.emit()


func get_current_floor_config():
	if level_registry == null:
		return null
	return level_registry.get_level_config(current_floor_id)


func set_player_input_enabled(enabled: bool) -> void:
	if player_ref:
		player_ref.set_process_input(enabled)
		if not enabled:
			player_ref.set_physics_process(false)
		else:
			player_ref.set_physics_process(true)


# --- Sublevel Transition Callbacks ---

func _on_enter_sublevel_transition_finished() -> void:
	# Load and instantiate the sublevel scene
	if not current_sublevel or current_sublevel.scene_path.is_empty():
		push_error("LevelManager: No valid sublevel config for enter transition")
		set_player_input_enabled(true)
		current_state = GameFlowState.PLAYING_MAIN_LEVEL
		return
	var sublevel_packed := load(current_sublevel.scene_path) as PackedScene
	if not sublevel_packed:
		push_error("LevelManager: Failed to load sublevel scene: " + current_sublevel.scene_path)
		set_player_input_enabled(true)
		current_state = GameFlowState.PLAYING_MAIN_LEVEL
		return
	# Instantiate sublevel scene
	_sublevel_scene_root = sublevel_packed.instantiate()
	get_tree().current_scene.add_child(_sublevel_scene_root)
	# Hide main level content if needed (player stays)
	if _current_scene_root:
		_current_scene_root.visible = false
	# Apply camera perspective for this sublevel type
	var cam_type: int = current_sublevel.sublevel_type
	camera_controller.apply_sublevel_perspective(cam_type)
	# Update state and enable input
	current_state = GameFlowState.PLAYING_SUBLEVEL
	set_player_input_enabled(true)
	sublevel_entered.emit(current_sublevel)


func _on_exit_sublevel_transition_finished() -> void:
	# Unload sublevel scene
	if _sublevel_scene_root and is_instance_valid(_sublevel_scene_root):
		_sublevel_scene_root.queue_free()
		_sublevel_scene_root = null
	# Reset camera to main level perspective
	camera_controller.reset_to_main_level()
	# Restore main level visibility
	if _current_scene_root:
		_current_scene_root.visible = true
	# Exit sublevel in checkpoint system
	checkpoint_system.exit_sublevel(player_ref.global_position if player_ref else Vector2.ZERO)
	# Mark sublevel as completed in progress data
	if current_sublevel:
		floor_progress.mark_sublevel_completed(current_floor_id, current_sublevel.sublevel_id)
	# Re-enable input and restore state
	set_player_input_enabled(true)
	var completed_sublevel = current_sublevel
	current_sublevel = null
	current_state = GameFlowState.PLAYING_MAIN_LEVEL
	sublevel_completed.emit(completed_sublevel)


# --- Signal Handlers (permanent connections) ---

func _on_load_failed(path: String, error: String) -> void:
	push_error("LevelManager: Failed to load scene '%s': %s" % [path, error])
	if current_state == GameFlowState.LOADING:
		current_state = GameFlowState.PLAYING_MAIN_LEVEL


func _on_checkpoint_activated(checkpoint_id: int, position: Vector2) -> void:
	floor_progress.active_checkpoints[current_floor_id] = checkpoint_id
	save_progress()


func _on_camera_ready(_sublevel_type) -> void:
	pass


# --- Private Methods ---

func _on_entre_nivel_exit_triggered(_trigger) -> void:
	exit_entre_nivel()


func _on_scene_loaded(packed_scene: PackedScene) -> void:
	# Disconnect the signal to avoid duplicate connections on next load
	if scene_loader.scene_loaded.is_connected(_on_scene_loaded):
		scene_loader.scene_loaded.disconnect(_on_scene_loaded)

	# If we're coming from a floor completion (entre_nivel load), handle that separately
	if current_state == GameFlowState.TRANSITION_TO_ENTRE_NIVEL:
		# Remove old scene
		if _current_scene_root and is_instance_valid(_current_scene_root):
			scene_loader.unload_scene(_current_scene_root)
			_current_scene_root = null
		# Instantiate entre_nivel scene
		var new_scene := packed_scene.instantiate()
		get_tree().root.add_child(new_scene)
		_current_scene_root = new_scene
		current_state = GameFlowState.ENTRE_NIVEL
		entre_nivel_entered.emit()
		# Find and connect exit trigger in entre_nivel scene
		var exit_triggers := _current_scene_root.find_children("*", "Area2D", true, false)
		for trigger in exit_triggers:
			if trigger.has_method("_on_body_entered") and trigger.get("target_type") != null:
				if trigger.target_type == 2:  # NEXT_FLOOR
					if not trigger.triggered.is_connected(_on_entre_nivel_exit_triggered):
						trigger.triggered.connect(_on_entre_nivel_exit_triggered)
		# Preload next floor during entre_nivel
		var next_floor_id := current_floor_id + 1
		if level_registry:
			var next_config = level_registry.get_level_config(next_floor_id)
			if next_config:
				scene_loader.preload_scene(next_config.scene_path)
		return

	# Normal floor loading
	# Remove old scene if exists
	if _current_scene_root and is_instance_valid(_current_scene_root):
		scene_loader.unload_scene(_current_scene_root)
		_current_scene_root = null

	# Instantiate new scene
	var new_scene := packed_scene.instantiate()
	get_tree().root.add_child(new_scene)
	_current_scene_root = new_scene

	# Find player reference
	player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Setup camera controller with the player's camera
	if player_ref:
		var camera := player_ref.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera_controller.setup_camera(camera)
		else:
			var new_camera := Camera2D.new()
			new_camera.name = "Camera2D"
			player_ref.add_child(new_camera)
			new_camera.make_current()
			camera_controller.setup_camera(new_camera)

	# Initialize checkpoint system with level bounds
	var config = get_current_floor_config()
	if config and player_ref:
		var start_pos := player_ref.global_position
		var map_start_x := 0.0
		var map_end_x: float = config.map_length_px
		checkpoint_system.initialize_for_level(start_pos, map_start_x, map_end_x)

	# Find and connect TransitionTrigger nodes (Area2D nodes with triggered signal)
	var triggers := _current_scene_root.find_children("*", "Area2D", true, false)
	for trigger in triggers:
		if trigger.has_signal("triggered") and trigger.get("target_type") != null:
			if not trigger.triggered.is_connected(enter_sublevel):
				trigger.triggered.connect(enter_sublevel)

	# Find CheckpointMarker nodes and register with checkpoint_system
	var markers := _current_scene_root.find_children("*", "Area2D", true, false)
	var checkpoint_markers: Array = []
	for marker in markers:
		if marker.has_method("activate") and marker.has_signal("marker_activated"):
			checkpoint_markers.append(marker)
	checkpoint_system.checkpoint_markers = checkpoint_markers

	# Transition to playing state and emit signal
	current_state = GameFlowState.PLAYING_MAIN_LEVEL
	floor_started.emit(current_floor_id)
