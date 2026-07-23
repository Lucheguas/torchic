class_name CheckpointSystem
extends Node

## Gestiona checkpoints del nivel principal y subniveles.
## Activa checkpoints automáticamente basándose en el progreso horizontal del jugador.

# --- Signals ---
signal checkpoint_activated(checkpoint_id: int, position: Vector2)
signal respawn_requested(position: Vector2)

# --- State ---
var active_checkpoint_position: Vector2 = Vector2.ZERO
var has_active_checkpoint: bool = false
var level_start_position: Vector2 = Vector2.ZERO
var sublevel_start_position: Vector2 = Vector2.ZERO
var is_in_sublevel: bool = false

# --- Main Level Checkpoint State ---
var checkpoint_markers: Array = []  # Array[CheckpointMarker] - typed once CheckpointMarker exists
var _map_start_x: float = 0.0
var _map_end_x: float = 0.0
var _checkpoint_1_active: bool = false
var _checkpoint_2_active: bool = false


## Resets all checkpoint state for a new level.
func initialize_for_level(start_pos: Vector2, map_start_x: float, map_end_x: float) -> void:
	level_start_position = start_pos
	active_checkpoint_position = start_pos
	has_active_checkpoint = false
	is_in_sublevel = false
	_map_start_x = map_start_x
	_map_end_x = map_end_x
	_checkpoint_1_active = false
	_checkpoint_2_active = false


## Calculates the player's progress through the level as a value between 0.0 and 1.0.
func calculate_progress(player_x: float) -> float:
	var total_distance := _map_end_x - _map_start_x
	if total_distance <= 0.0:
		return 0.0
	return clampf((player_x - _map_start_x) / total_distance, 0.0, 1.0)


## Updates checkpoint activation based on player's horizontal position.
## Checkpoint 1 activates at 33% progress, checkpoint 2 at 66%.
func update_checkpoints(player_x: float) -> void:
	var progress := calculate_progress(player_x)
	if progress >= 0.33 and not _checkpoint_1_active:
		_activate_checkpoint(0)
	if progress >= 0.66 and not _checkpoint_2_active:
		_activate_checkpoint(1)


## Returns the appropriate respawn position based on current state.
## Priority: sublevel start > active checkpoint > level start.
func get_respawn_position() -> Vector2:
	if is_in_sublevel:
		return sublevel_start_position
	if has_active_checkpoint:
		return active_checkpoint_position
	return level_start_position


## Registers entry into a sublevel, saving the entry checkpoint and sublevel start position.
func enter_sublevel(entry_position: Vector2, sublevel_start: Vector2) -> void:
	active_checkpoint_position = entry_position
	has_active_checkpoint = true
	sublevel_start_position = sublevel_start
	is_in_sublevel = true


## Registers exit from a sublevel, restoring main level context.
func exit_sublevel(return_position: Vector2) -> void:
	active_checkpoint_position = return_position
	is_in_sublevel = false


# --- Private ---

func _activate_checkpoint(index: int) -> void:
	if index == 0:
		_checkpoint_1_active = true
	elif index == 1:
		_checkpoint_2_active = true
	if index < checkpoint_markers.size():
		var marker = checkpoint_markers[index]
		marker.activate()
		active_checkpoint_position = marker.global_position
	has_active_checkpoint = true
	checkpoint_activated.emit(index, active_checkpoint_position)
