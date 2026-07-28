class_name LevelConfigData
extends Resource
## Configuración de un piso: qué escena cargar, su largo y a qué entre_nivel va.

@export var floor_id: int = 0
@export var scene_path: String = ""
@export var entre_nivel_scene_path: String = "res://scenes/entre_nivel.tscn"
@export var map_length_px: float = 5000.0
