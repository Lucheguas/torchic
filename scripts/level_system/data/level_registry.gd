class_name LevelRegistry
extends Resource
## Lista de pisos del juego. Recurso guardado en resources/level_registry.tres.

@export var levels: Array[LevelConfigData] = []


func get_level_config(floor_id: int) -> LevelConfigData:
	for config in levels:
		if config.floor_id == floor_id:
			return config
	return null
