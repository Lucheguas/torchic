class_name KillZone
extends Area2D
## Kills the player on contact. Delegates respawn to LevelManager.handle_player_death().
## The respawn_position export is preserved for scene compatibility only.

@export var respawn_position: Vector2 = Vector2(100, 570)  # retained but unused


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	if not _has_level_manager():
		push_error("KillZone: LevelManager autoload not available; skipping respawn.")
		return
	LevelManager.handle_player_death()


func _has_level_manager() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	return tree.root.has_node("LevelManager")
