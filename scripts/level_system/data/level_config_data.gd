class_name LevelConfigData
extends Resource

enum BossType { MINI, MAJOR }
enum Phase { FOREST, CAVE, LABORATORY }

@export var floor_id: int = 0
@export var phase: Phase = Phase.FOREST
@export var scene_path: String = ""
@export var sublevels: Array[SubLevelConfig] = []
@export var boss_type: BossType = BossType.MINI
@export var entre_nivel_scene_path: String = "res://scenes/entre_nivel.tscn"
@export var map_length_px: float = 5000.0


func get_phase_for_floor(floor_id: int) -> Phase:
	if floor_id <= 5:
		return Phase.FOREST
	elif floor_id <= 10:
		return Phase.CAVE
	else:
		return Phase.LABORATORY


func is_major_boss_floor() -> bool:
	return floor_id in [5, 10, 15]


func validate() -> Array[String]:
	var errors: Array[String] = []
	if floor_id <= 0:
		errors.append("Floor %d: floor_id must be positive" % floor_id)
	if scene_path.is_empty():
		errors.append("Floor %d: scene_path is empty" % floor_id)
	elif not ResourceLoader.exists(scene_path):
		errors.append("Floor %d: scene_path '%s' does not exist" % [floor_id, scene_path])
	for sublevel in sublevels:
		var sub_errors := sublevel.validate(floor_id)
		errors.append_array(sub_errors)
	if is_major_boss_floor() and boss_type != BossType.MAJOR:
		errors.append("Floor %d: should have MAJOR boss type" % floor_id)
	return errors
