class_name CameraController
extends Node

signal camera_ready(sublevel_type: SubLevelType)
signal camera_reset()

var _camera: Camera2D = null

enum SubLevelType { CHASE, INFILTRATION, PRECISION_AIMING, ENVIRONMENTAL_PUZZLE }

const CAMERA_CONFIGS: Dictionary = {
	SubLevelType.CHASE: {
		"zoom": Vector2(1.5, 1.5),
		"offset": Vector2(0, -100),
		"rotation": 0.0,
	},
	SubLevelType.INFILTRATION: {
		"zoom": Vector2(1.2, 1.2),
		"offset": Vector2(0, -50),
		"rotation": 0.0,
	},
	SubLevelType.PRECISION_AIMING: {
		"zoom": Vector2(0.7, 0.7),
		"offset": Vector2(0, -200),
		"rotation": 0.0,
	},
	SubLevelType.ENVIRONMENTAL_PUZZLE: {
		"zoom": Vector2(0.5, 0.5),
		"offset": Vector2.ZERO,
		"rotation": 0.0,
	},
}


func setup_camera(camera: Camera2D) -> void:
	_camera = camera


func apply_sublevel_perspective(type: SubLevelType) -> void:
	if not _camera:
		return
	var config: Dictionary = CAMERA_CONFIGS[type]
	_camera.zoom = config["zoom"]
	_camera.offset = config["offset"]
	_camera.rotation = config["rotation"]
	camera_ready.emit(type)


func reset_to_main_level() -> void:
	if not _camera:
		return
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.offset = Vector2.ZERO
	_camera.rotation = 0.0
	camera_reset.emit()


func get_perspective_for_type(type: SubLevelType) -> Dictionary:
	return CAMERA_CONFIGS.get(type, {})
