class_name CheckpointMarker
extends Area2D
## Area2D node placed in levels to define checkpoint positions.
## Activates automatically when the player reaches it, providing visual feedback
## via color change and wave animation on the flag sprite.

# --- Signals ---
signal marker_activated()

# --- State ---
var is_active: bool = false

# --- References ---
@onready var flag_sprite: Sprite2D = $CheckpointFlag
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Constants ---
const INACTIVE_COLOR := Color(0.5, 0.5, 0.5, 1.0)
const ACTIVE_COLOR := Color(0.2, 0.9, 0.2, 1.0)


func _ready() -> void:
	flag_sprite.modulate = INACTIVE_COLOR
	body_entered.connect(_on_body_entered)


func activate() -> void:
	if is_active:
		return
	is_active = true
	flag_sprite.modulate = ACTIVE_COLOR
	animation_player.play("wave")
	marker_activated.emit()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_active:
		activate()
