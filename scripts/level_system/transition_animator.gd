class_name TransitionAnimator
extends Node
## Espera entre escenas. Hoy solo mide el tiempo de la transición y avisa al
## terminar; el efecto visual todavía no existe.

signal transition_finished()

const TRANSITION_DURATION: float = 1.5

var _is_transitioning: bool = false


func play_transition() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var tween := create_tween()
	tween.tween_interval(TRANSITION_DURATION)
	tween.tween_callback(_on_transition_complete)


func _on_transition_complete() -> void:
	_is_transitioning = false
	transition_finished.emit()
