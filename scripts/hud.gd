extends CanvasLayer
## In-game HUD. Shows the remaining lives in the top-left corner and updates
## whenever LevelManager reports a change.

@onready var _lives_label: Label = $LivesLabel


func _ready() -> void:
	LevelManager.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(LevelManager.get_lives())


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "Vidas: %d" % lives
