class_name TransitionTrigger
extends Area2D
## Trigger zone that initiates level transitions when the player enters.
## Emits a signal with a self-reference so the Level_Manager can read
## target_type and sublevel_config to decide what to load next.

signal triggered(trigger: TransitionTrigger)

enum TargetType { SUBLEVEL, ENTRE_NIVEL, NEXT_FLOOR }

@export var target_type: TargetType = TargetType.SUBLEVEL
@export var sublevel_config: SubLevelConfig = null
@export var transition_visual: TransitionAnimator.TransitionType = TransitionAnimator.TransitionType.DOOR


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		triggered.emit(self)
		# Double-trigger prevention: disconnect after first activation
		body_entered.disconnect(_on_body_entered)
