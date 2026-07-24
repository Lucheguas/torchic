class_name PlayerTrigger
extends Area2D
## Base class for Area2D triggers that fire once when the player enters.
## Subclasses override _on_player_entered(body) to define the effect.

var _fired: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_handle_body_entered):
		body_entered.connect(_handle_body_entered)


## Virtual method. Subclasses override this to define the trigger effect.
## Called exactly once, on the first CharacterBody2D in the "player" group
## to enter the trigger area.
func _on_player_entered(_body: Node2D) -> void:
	pass


func _handle_body_entered(body: Node2D) -> void:
	if _fired:
		return
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	_fired = true
	_on_player_entered(body)
	if body_entered.is_connected(_handle_body_entered):
		body_entered.disconnect(_handle_body_entered)
