extends Node2D
## Main scene startup script. Triggers game flow via the LevelManager autoload.


func _ready() -> void:
	# Wait one frame to ensure all autoloads are fully initialized
	await get_tree().process_frame
	LevelManager.start_game(false)
