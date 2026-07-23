class_name SublevelExitTrigger
extends Area2D
## Simple trigger that calls LevelManager.complete_sublevel() when the player
## reaches the end of a sublevel. Place this at the exit point of any sublevel scene.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		LevelManager.complete_sublevel()
		# Prevent double-triggering
		body_entered.disconnect(_on_body_entered)
