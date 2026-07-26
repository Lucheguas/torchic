# GdUnit4 test suite
extends GdUnitTestSuite

## El knockback empuja al enemigo en la dirección del golpe y domina sobre la
## patrulla mientras dura, luego el enemigo retoma su comportamiento normal.

const ENEMY_PATH := "res://scenes/enemy_basic.tscn"


func _spawn_enemy() -> EnemyBasic:
	var enemy: EnemyBasic = auto_free(load(ENEMY_PATH).instantiate()) as EnemyBasic
	add_child(enemy)
	return enemy


## Empujado a la izquierda, el enemigo debe terminar a la izquierda de su origen
## pese a que la patrulla por defecto arranca hacia la derecha.
func test_knockback_moves_enemy_against_default_patrol() -> void:
	var enemy := _spawn_enemy()
	var start_x := enemy.global_position.x

	enemy.apply_knockback(-1.0)
	await await_millis(80)

	assert_float(enemy.global_position.x).is_less(start_x)


## Un valor de dirección positivo empuja hacia la derecha.
func test_knockback_direction_is_signed() -> void:
	var enemy := _spawn_enemy()
	var start_x := enemy.global_position.x

	enemy.apply_knockback(1.0)
	await await_millis(80)

	assert_float(enemy.global_position.x).is_greater(start_x)
