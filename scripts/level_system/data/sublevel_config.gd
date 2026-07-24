class_name SubLevelConfig
extends Resource
## Configuration resource for a single sub-level within a floor.
## Defines the scene path, transition style, and time limit settings.

# --- Local Enums (will reference TransitionAnimator.TransitionType once that script exists) ---
enum TransitionType { DOOR, PIPE, DATA_PORTAL }

# --- Exports ---
@export var sublevel_id: String = ""
@export var scene_path: String = ""
@export var transition_type: TransitionType = TransitionType.DOOR
@export var has_time_limit: bool = false
@export var time_limit_seconds: float = 0.0

## Validates the sub-level configuration and returns an array of error messages.
## Returns an empty array if the configuration is valid.
func validate(parent_floor_id: int) -> Array[String]:
	var errors: Array[String] = []
	if sublevel_id.is_empty():
		errors.append("Floor %d: sublevel has empty sublevel_id" % parent_floor_id)
	if scene_path.is_empty():
		errors.append("Floor %d, SubLevel '%s': scene_path is empty" % [parent_floor_id, sublevel_id])
	elif not ResourceLoader.exists(scene_path):
		errors.append("Floor %d, SubLevel '%s': scene_path '%s' does not exist" % [parent_floor_id, sublevel_id, scene_path])
	if has_time_limit and time_limit_seconds <= 0.0:
		errors.append("Floor %d, SubLevel '%s': has_time_limit is true but time_limit_seconds <= 0" % [parent_floor_id, sublevel_id])
	return errors
