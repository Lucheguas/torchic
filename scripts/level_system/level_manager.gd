extends Node
## Autoload singleton that orchestrates the complete level flow:
## floor loading, sub-level transitions, entre-nivel zones, checkpoints,
## and persistent save data.
## Access globally via the "LevelManager" autoload name (no class_name needed).

# --- Signals ---
signal floor_started(floor_id: int)
signal floor_completed(floor_id: int)
signal entre_nivel_entered()
signal entre_nivel_exited()
signal player_respawned(position: Vector2)

# --- State Machine ---
enum GameFlowState {
	LOADING,
	PLAYING_MAIN_LEVEL,
	TRANSITION_TO_ENTRE_NIVEL,
	ENTRE_NIVEL,
	RESPAWNING,
}

const STARTING_LIVES: int = 3

var current_state: GameFlowState = GameFlowState.LOADING
var current_floor_id: int = 1
var player_ref: CharacterBody2D = null
var _current_scene_root: Node = null
var _lives: int = STARTING_LIVES
## The weapon the player currently carries, tracked so it survives scene changes
## (each scene embeds its own player with the default weapon). Only meaningful
## once _weapon_overridden is true; null then means the player is unarmed.
var equipped_weapon = null  # MeleeWeapon
var _weapon_overridden: bool = false
var _game_over_screen: Node = null
var _hud: Node = null

# Emitted whenever the life count changes (respawn or new game), for an optional HUD.
signal lives_changed(lives: int)

# --- Child Node References ---
@onready var checkpoint_system: Node = $CheckpointSystem
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

	# Start every run from scratch: ignore any saved progress on boot so testing
	# always begins at floor 1 with default state. start_game(true) can still load
	# the save explicitly for a future "continue" feature.
	var fpd_script = load("res://scripts/level_system/data/floor_progress_data.gd")
	if fpd_script:
		floor_progress = fpd_script.new()
	else:
		push_error("LevelManager: Could not load FloorProgressData script")

	# Connect permanent subsystem signals
	scene_loader.load_failed.connect(_on_load_failed)


## Standalone-scene bootstrap (boot F6, or a floor scene added directly to the
## tree): retries every frame until a player-bearing scene the manager did not
## load appears, then arms the death pipeline once. Self-limiting — becomes a
## no-op as soon as _current_scene_root is set (by this bootstrap or by a normal
## SceneLoader load).
func _physics_process(_delta: float) -> void:
	if _current_scene_root == null:
		_bootstrap_standalone_scene()


# --- Public Methods ---

func start_game(from_save: bool = false) -> void:
	var fpd_script = load("res://scripts/level_system/data/floor_progress_data.gd")
	if from_save:
		floor_progress = fpd_script.load_from_disk()
	else:
		# New game: always start from scratch, ignoring any prior progress so
		# pressing "Inicio" in the menu begins a fresh run every time.
		floor_progress = fpd_script.new()
	_lives = STARTING_LIVES
	# A fresh run starts with the default weapon baked into the player scene.
	equipped_weapon = null
	_weapon_overridden = false
	_show_hud()
	lives_changed.emit(_lives)
	current_floor_id = floor_progress.current_floor
	load_floor(current_floor_id)


## Current remaining lives. Used by the HUD to render its initial value.
func get_lives() -> int:
	return _lives


func _show_hud() -> void:
	if _hud and is_instance_valid(_hud):
		return
	_hud = load("res://scenes/hud.tscn").instantiate()
	get_tree().root.add_child(_hud)


func _hide_hud() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
		_hud = null


func load_floor(floor_id: int) -> void:
	current_state = GameFlowState.LOADING
	current_floor_id = floor_id
	var config = get_current_floor_config()
	if config == null:
		# Requested floor not registered. Fall back to floor 1 and rewind saved
		# progress so the save file stays consistent with what actually exists.
		push_warning(
			"LevelManager: No config for floor_id %d; falling back to floor 1."
			% floor_id
		)
		current_floor_id = 1
		if floor_progress:
			floor_progress.current_floor = 1
			floor_progress.save_to_disk()
		config = get_current_floor_config()
		if config == null:
			push_error("LevelManager: Fallback floor 1 also has no config; aborting load.")
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
	transition_animator.play_transition()
	await transition_animator.transition_finished
	# Load the entre_nivel scene
	var entre_nivel_path: String = config.entre_nivel_scene_path if config else "res://scenes/entre_nivel.tscn"
	if not scene_loader.scene_loaded.is_connected(_on_scene_loaded):
		scene_loader.scene_loaded.connect(_on_scene_loaded)
	scene_loader.request_load(entre_nivel_path)


func exit_entre_nivel() -> void:
	if current_state != GameFlowState.ENTRE_NIVEL:
		push_warning("LevelManager: exit_entre_nivel called while not in ENTRE_NIVEL state")
		return
	entre_nivel_exited.emit()
	current_state = GameFlowState.LOADING
	var next_floor_id := current_floor_id + 1
	if level_registry == null or level_registry.get_level_config(next_floor_id) == null:
		# Se terminó el último piso registrado: fin de la partida.
		_finish_run()
		return
	load_floor(next_floor_id)


## Último piso superado: desmonta el entre_nivel y vuelve al menú.
func _finish_run() -> void:
	if _current_scene_root and is_instance_valid(_current_scene_root):
		scene_loader.unload_scene(_current_scene_root)
		_current_scene_root = null
	player_ref = null
	return_to_menu()


func handle_player_death() -> void:
	if not player_ref:
		push_error("LevelManager: handle_player_death sin player_ref; la muerte se ignoró.")
		return
	# Solo se muere jugando. Durante cargas, transiciones o el propio respawn el
	# flujo está reposicionando al jugador, y un solape suelto (KillZone o
	# enemigo) lo teletransportaría a un checkpoint a media transición.
	if not _is_playing():
		return
	_lives -= 1
	lives_changed.emit(_lives)
	if _lives > 0:
		_respawn_at_checkpoint()
	else:
		_trigger_game_over()


func _respawn_at_checkpoint() -> void:
	current_state = GameFlowState.RESPAWNING
	var respawn_pos: Vector2 = checkpoint_system.get_respawn_position()
	player_ref.global_position = respawn_pos
	player_ref.velocity = Vector2.ZERO
	current_state = GameFlowState.PLAYING_MAIN_LEVEL
	player_respawned.emit(respawn_pos)


## No lives left: tear down the level and show the Game Over screen.
func _trigger_game_over() -> void:
	current_state = GameFlowState.LOADING
	set_player_input_enabled(false)
	_hide_hud()
	if _current_scene_root and is_instance_valid(_current_scene_root):
		scene_loader.unload_scene(_current_scene_root)
		_current_scene_root = null
	player_ref = null
	var go_screen: Node = load("res://scenes/game_over.tscn").instantiate()
	get_tree().root.add_child(go_screen)
	_game_over_screen = go_screen


## Called by the Game Over screen's button: clean up and return to the main menu.
func return_to_menu() -> void:
	if _game_over_screen and is_instance_valid(_game_over_screen):
		_game_over_screen.queue_free()
		_game_over_screen = null
	_hide_hud()
	current_state = GameFlowState.LOADING
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## True while the player has actual control of the character.
func _is_playing() -> bool:
	return current_state == GameFlowState.PLAYING_MAIN_LEVEL


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


## Records the weapon the player is now carrying (null = unarmed) so it carries
## across floors. Called by the player whenever it picks up or drops a weapon.
func set_equipped_weapon(weapon) -> void:
	equipped_weapon = weapon
	_weapon_overridden = true


## Re-applies the carried weapon onto the current player's MeleeAttack. Each
## scene embeds its own player with the default weapon, so this restores the
## player's real weapon every time a new floor or the entre-nivel is set up.
## Before any pickup/drop (_weapon_overridden false) the scene default is kept.
func _apply_equipped_weapon() -> void:
	if not _weapon_overridden or player_ref == null:
		return
	var melee := player_ref.get_node_or_null("MeleeAttack")
	if melee:
		melee.weapon = equipped_weapon


## Resolves player_ref from the "player" group in the current scene and makes
## sure the player has a current Camera2D (creates one if the scene omitted it).
## Used by both the main floor load and the entre_nivel load.
func _setup_player_and_camera() -> void:
	player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player_ref:
		return
	var camera := player_ref.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		player_ref.add_child(camera)
	camera.make_current()
	_apply_equipped_weapon()


## Connects the level nodes that both the SceneLoader path and the standalone
## bootstrap need: the end-of-floor transition trigger and checkpoint markers.
func _wire_level_nodes(root: Node) -> void:
	var areas := root.find_children("*", "Area2D", true, false)
	for trigger in areas:
		if trigger is TransitionTrigger:
			if not trigger.triggered.is_connected(_on_next_floor_triggered):
				trigger.triggered.connect(_on_next_floor_triggered)

	# CheckpointMarkers self-activate on player contact and emit marker_activated;
	# connect that so the reached checkpoint becomes the respawn point.
	for marker in areas:
		if marker is CheckpointMarker:
			if not marker.marker_activated.is_connected(_on_checkpoint_marker_reached):
				marker.marker_activated.connect(_on_checkpoint_marker_reached.bind(marker))


## Boot F6: the floor scene is already in the tree but the manager never loaded
## it, so player_ref would stay null and every death would be lost silently.
## Runs once at startup so initialize_for_level() captures the player's spawn
## position (not a later fall position).
func _bootstrap_standalone_scene() -> void:
	if _current_scene_root != null:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	# The floor scene root owns the instanced player. Prefer it over
	# get_tree().current_scene, which is null when the scene is added to the tree
	# directly (test harness) instead of loaded as the active scene.
	var scene_root: Node = player.owner if player.owner != null else get_tree().current_scene
	if scene_root == null:
		return
	_current_scene_root = scene_root
	_setup_player_and_camera()
	var config = get_current_floor_config()
	if config:
		checkpoint_system.initialize_for_level(
			player_ref.global_position, 0.0, config.map_length_px
		)
	_wire_level_nodes(_current_scene_root)
	current_state = GameFlowState.PLAYING_MAIN_LEVEL
	floor_started.emit(current_floor_id)


# --- Signal Handlers (permanent connections) ---

func _on_load_failed(path: String, error: String) -> void:
	push_error("LevelManager: Failed to load scene '%s': %s" % [path, error])
	if current_state == GameFlowState.LOADING:
		current_state = GameFlowState.PLAYING_MAIN_LEVEL


## Called when the player reaches a CheckpointMarker. Updates the respawn point
## so a subsequent death (e.g. falling into a KillZone) returns the player here.
func _on_checkpoint_marker_reached(marker: Node) -> void:
	checkpoint_system.set_reached_checkpoint(marker.global_position)


# --- Private Methods ---

func _on_entre_nivel_exit_triggered(_trigger) -> void:
	exit_entre_nivel()


func _on_next_floor_triggered(_trigger) -> void:
	if current_state == GameFlowState.PLAYING_MAIN_LEVEL:
		complete_floor()


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
		var entre_nivel_scene := packed_scene.instantiate()
		get_tree().root.add_child(entre_nivel_scene)
		_current_scene_root = entre_nivel_scene
		current_state = GameFlowState.ENTRE_NIVEL
		# The entre_nivel scene embeds its own Player; wire up the reference and camera.
		_setup_player_and_camera()
		entre_nivel_entered.emit()
		# Find and connect exit trigger in entre_nivel scene
		var exit_triggers := _current_scene_root.find_children("*", "Area2D", true, false)
		for trigger in exit_triggers:
			if trigger is TransitionTrigger:
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

	# Find player reference and ensure it has a current camera
	_setup_player_and_camera()

	# Initialize checkpoint system with level bounds
	var config = get_current_floor_config()
	if config and player_ref:
		var start_pos := player_ref.global_position
		var map_start_x := 0.0
		var map_end_x: float = config.map_length_px
		checkpoint_system.initialize_for_level(start_pos, map_start_x, map_end_x)

	# Wire triggers and checkpoint markers (shared with the standalone bootstrap).
	_wire_level_nodes(_current_scene_root)

	# Transition to playing state and emit signal
	current_state = GameFlowState.PLAYING_MAIN_LEVEL
	floor_started.emit(current_floor_id)
