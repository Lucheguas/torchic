class_name KillZone
extends Area2D
## Kills the player and respawns them at the last checkpoint or spawn point.
## Used for pits/abysses in levels.

@export var respawn_position: Vector2 = Vector2(100, 570)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		_respawn_player(body)


func _respawn_player(player: CharacterBody2D) -> void:
	# Check if checkpoint system has an active checkpoint
	var checkpoint_pos := _get_last_checkpoint()
	if checkpoint_pos != Vector2.ZERO:
		player.global_position = checkpoint_pos
	else:
		player.global_position = respawn_position
	player.velocity = Vector2.ZERO


func _get_last_checkpoint() -> Vector2:
	# Search all CheckpointMarker nodes in the tree
	var latest_active: Node2D = null
	var all_nodes := _find_checkpoints(get_tree().current_scene)
	for cp in all_nodes:
		if cp.is_active:
			if latest_active == null or cp.global_position.x > latest_active.global_position.x:
				latest_active = cp
	if latest_active:
		return latest_active.global_position + Vector2(0, -30)
	return Vector2.ZERO


func _find_checkpoints(node: Node) -> Array[CheckpointMarker]:
	var result: Array[CheckpointMarker] = []
	if node is CheckpointMarker:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_checkpoints(child))
	return result
