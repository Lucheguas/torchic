extends Control
## Game Over screen. Shown by LevelManager when the player runs out of lives.
## The single button returns to the main menu (which starts a fresh run).

@onready var _menu_button: Button = $CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	_menu_button.pressed.connect(_on_menu_pressed)
	_menu_button.grab_focus()


func _on_menu_pressed() -> void:
	LevelManager.return_to_menu()
