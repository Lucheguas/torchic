class_name LevelRegistry
extends Resource

@export var levels: Array[LevelConfigData] = []


func get_level_config(floor_id: int) -> LevelConfigData:
	for config in levels:
		if config.floor_id == floor_id:
			return config
	return null


func get_total_floors() -> int:
	return levels.size()


func validate() -> Array[String]:
	var errors: Array[String] = []
	for config in levels:
		var config_errors := config.validate()
		errors.append_array(config_errors)
	return errors
