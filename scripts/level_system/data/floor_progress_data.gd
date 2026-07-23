class_name FloorProgressData
extends Resource

@export var highest_floor_reached: int = 1
@export var current_floor: int = 1
@export var completed_sublevels: Dictionary = {}  # {floor_id: [sublevel_ids]}
@export var active_checkpoints: Dictionary = {}   # {floor_id: checkpoint_index}

# --- Player State (transferred between scenes) ---
@export var player_hp: int = 100
@export var player_tokens: int = 0
@export var player_exp: int = 0
@export var player_level: int = 1
@export var player_equipment: Array[String] = []

const SAVE_PATH: String = "user://floor_progress.tres"


func update_floor_completed(floor_id: int) -> void:
	if floor_id > highest_floor_reached:
		highest_floor_reached = floor_id
	current_floor = mini(floor_id + 1, 15)


func mark_sublevel_completed(floor_id: int, sublevel_id: String) -> void:
	if not completed_sublevels.has(floor_id):
		completed_sublevels[floor_id] = []
	if sublevel_id not in completed_sublevels[floor_id]:
		completed_sublevels[floor_id].append(sublevel_id)


func save_to_disk() -> Error:
	return ResourceSaver.save(self, SAVE_PATH)


static func load_from_disk() -> FloorProgressData:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH)
		if loaded is FloorProgressData:
			return loaded
	return FloorProgressData.new()


func capture_player_state(player: CharacterBody2D) -> void:
	# Called before scene transitions to snapshot player data
	# Actual fields depend on player script implementation
	pass


func restore_player_state(player: CharacterBody2D) -> void:
	# Called after scene transitions to restore player data
	pass
