class_name TransitionAnimator
extends Node

signal transition_started(type: TransitionType)
signal transition_finished()

const TRANSITION_DURATION: float = 1.5

enum TransitionType { DOOR, PIPE, DATA_PORTAL }

var _is_transitioning: bool = false
var _tween: Tween = null

func play_enter_transition(type: TransitionType) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit(type)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_show_transition_effect.bind(type))
	_tween.tween_interval(TRANSITION_DURATION)
	_tween.tween_callback(_on_transition_complete)

func play_exit_transition(type: TransitionType) -> void:
	play_enter_transition(type)

func is_transitioning() -> bool:
	return _is_transitioning

func _show_transition_effect(type: TransitionType) -> void:
	# Visual effect based on transition type - placeholder
	pass

func _on_transition_complete() -> void:
	_is_transitioning = false
	transition_finished.emit()
