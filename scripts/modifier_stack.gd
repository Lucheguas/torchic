class_name ModifierStack
extends RefCounted
## Holds equipment- and level-derived player modifiers with clamped setters.
## Owned by MovementController via composition.

var base_speed: float = 1.0
var speed_modifier: float = 0.0
var jump_height_bonus: float = 0.0
var double_jump_enabled: bool = false
var stomp_bounce_multiplier: float = 1.0


func set_base_speed(value: float) -> void:
	base_speed = clampf(value, 1.0, 1.7)


func set_speed_modifier(value: float) -> void:
	speed_modifier = clampf(value, 0.0, 0.5)


func set_jump_height_bonus(value: float) -> void:
	jump_height_bonus = clampf(value, 0.0, 1.0)


func set_double_jump_enabled(value: bool) -> void:
	double_jump_enabled = value


func set_stomp_bounce_multiplier(value: float) -> void:
	stomp_bounce_multiplier = clampf(value, 1.0, 2.0)
