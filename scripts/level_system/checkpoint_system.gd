class_name CheckpointSystem
extends Node

## Guarda el punto de reaparición del piso actual: el inicio del nivel hasta que
## el jugador toca un CheckpointMarker.

# --- State ---
var active_checkpoint_position: Vector2 = Vector2.ZERO
var has_active_checkpoint: bool = false
var level_start_position: Vector2 = Vector2.ZERO

var _map_start_x: float = 0.0
var _map_end_x: float = 0.0


## Resets all checkpoint state for a new level.
func initialize_for_level(start_pos: Vector2, map_start_x: float, map_end_x: float) -> void:
	level_start_position = start_pos
	active_checkpoint_position = start_pos
	has_active_checkpoint = false
	_map_start_x = map_start_x
	_map_end_x = map_end_x


## Calculates the player's progress through the level as a value between 0.0 and 1.0.
func calculate_progress(player_x: float) -> float:
	var total_distance := _map_end_x - _map_start_x
	if total_distance <= 0.0:
		return 0.0
	return clampf((player_x - _map_start_x) / total_distance, 0.0, 1.0)


## Returns the appropriate respawn position: checkpoint alcanzado si hay uno,
## si no el inicio del nivel.
func get_respawn_position() -> Vector2:
	if has_active_checkpoint:
		return active_checkpoint_position
	return level_start_position


## Sets the respawn point to a checkpoint the player physically reached.
## Called by LevelManager when a CheckpointMarker emits marker_activated.
func set_reached_checkpoint(checkpoint_position: Vector2) -> void:
	active_checkpoint_position = checkpoint_position
	has_active_checkpoint = true
