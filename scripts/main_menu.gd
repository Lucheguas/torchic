extends Control
## Main menu. A single "Inicio" button starts a brand-new run through the
## LevelManager and removes the menu from the tree.

@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	LevelManager.start_game(false)
	# The level is streamed into the tree root by the LevelManager, so this menu
	# stops being the current scene. Detach it before freeing so a later
	# change_scene_to_file (Game Over → menu) never frees an already-freed node.
	get_tree().current_scene = null
	queue_free()
