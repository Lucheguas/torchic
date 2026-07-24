class_name SublevelExitTrigger
extends PlayerTrigger
## Simple trigger that calls LevelManager.complete_sublevel() when the player
## reaches the end of a sublevel. Place this at the exit point of any sublevel scene.


func _on_player_entered(_body: Node2D) -> void:
	LevelManager.complete_sublevel()
