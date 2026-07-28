extends Node2D
## Floor 3 boss room. Keeps the level exit sealed until the boss is defeated.
## The exit is a NEXT_FLOOR TransitionTrigger with monitoring disabled in the
## scene; killing the boss opens it and reveals its door visual.

@onready var _exit: TransitionTrigger = $Spawners/LevelEnd
@onready var _boss: BaseEnemy = $Enemies/Boss


func _ready() -> void:
	# take_damage() queue_free()s the boss once its hp runs out; tree_exited is
	# the moment the fight is won.
	_boss.tree_exited.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	# The scene tearing down also frees the boss; ignore that case.
	if not is_instance_valid(_exit):
		return
	_exit.set_deferred("monitoring", true)
	var door := _exit.get_node_or_null("Visual")
	if door:
		door.visible = true
