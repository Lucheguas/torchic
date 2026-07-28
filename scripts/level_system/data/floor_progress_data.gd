class_name FloorProgressData
extends Resource
## Progreso persistido de la partida. Se guarda al completar un piso.

const TOTAL_FLOORS: int = 3

@export var highest_floor_reached: int = 1
@export var current_floor: int = 1

const SAVE_PATH: String = "user://floor_progress.tres"


func update_floor_completed(floor_id: int) -> void:
	if floor_id > highest_floor_reached:
		highest_floor_reached = floor_id
	current_floor = mini(floor_id + 1, TOTAL_FLOORS)


func save_to_disk() -> Error:
	return ResourceSaver.save(self, SAVE_PATH)


static func load_from_disk() -> FloorProgressData:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH)
		if loaded is FloorProgressData:
			return loaded
	return FloorProgressData.new()
