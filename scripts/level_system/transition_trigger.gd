class_name TransitionTrigger
extends PlayerTrigger
## Trigger zone that initiates level transitions when the player enters.
## Emits a signal with a self-reference so the Level_Manager can read
## target_type and sublevel_config to decide what to load next.

signal triggered(trigger: TransitionTrigger)

enum TargetType { SUBLEVEL, ENTRE_NIVEL, NEXT_FLOOR }

@export var target_type: TargetType = TargetType.SUBLEVEL
@export var sublevel_config: SubLevelConfig = null
@export var transition_visual: TransitionAnimator.TransitionType = TransitionAnimator.TransitionType.DOOR


func _on_player_entered(_body: Node2D) -> void:
	triggered.emit(self)
