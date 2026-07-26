# GdUnit4 test suite
extends GdUnitTestSuite

## Matriz de interacción de combate sobre BaseEnemy.take_damage():
##
## | tipo  | con armadura            | sin armadura |
## |-------|-------------------------|--------------|
## | STOMP | sobrevive, conserva     | muere        |
## | MELEE | sobrevive, pierde armad.| muere        |
##
## El rebote del jugador no se prueba aquí: es responsabilidad del
## MovementController y ocurre siempre, con o sin armadura.

const ENEMY_PATH := "res://scenes/enemy_basic.tscn"


func _spawn_enemy(armored: bool) -> EnemyBasic:
	var enemy: EnemyBasic = auto_free(load(ENEMY_PATH).instantiate()) as EnemyBasic
	enemy.has_armor = armored
	add_child(enemy)
	return enemy


func test_stomp_on_armored_enemy_is_absorbed() -> void:
	var enemy := _spawn_enemy(true)

	enemy.take_damage(1, BaseEnemy.DamageType.STOMP)

	assert_bool(enemy.is_queued_for_deletion()).is_false()
	assert_bool(enemy.has_armor).is_true()
	assert_int(enemy.hp).is_equal(1)


func test_melee_on_armored_enemy_breaks_armor_without_killing() -> void:
	var enemy := _spawn_enemy(true)
	var monitor := monitor_signals(enemy)

	enemy.take_damage(1, BaseEnemy.DamageType.MELEE)

	assert_bool(enemy.is_queued_for_deletion()).is_false()
	assert_bool(enemy.has_armor).is_false()
	assert_int(enemy.hp).is_equal(1)
	await assert_signal(monitor).is_emitted("armor_broken")


func test_melee_on_unarmored_enemy_kills() -> void:
	var enemy := _spawn_enemy(false)

	enemy.take_damage(1, BaseEnemy.DamageType.MELEE)

	assert_bool(enemy.is_queued_for_deletion()).is_true()


func test_stomp_on_unarmored_enemy_kills() -> void:
	var enemy := _spawn_enemy(false)

	enemy.take_damage(1, BaseEnemy.DamageType.STOMP)

	assert_bool(enemy.is_queued_for_deletion()).is_true()


func test_two_melee_hits_break_armor_then_kill() -> void:
	var enemy := _spawn_enemy(true)

	enemy.take_damage(1, BaseEnemy.DamageType.MELEE)
	enemy.take_damage(1, BaseEnemy.DamageType.MELEE)

	assert_bool(enemy.is_queued_for_deletion()).is_true()


## Propiedad: la armadura absorbe el pisotón entero, sea cual sea el daño.
## Ningún valor de amount debe atravesarla ni tocar el hp.
func test_armor_absorbs_any_stomp_amount(
	fuzzer := Fuzzers.rangei(1, 1000), fuzzer_iterations := 100
) -> void:
	var enemy := _spawn_enemy(true)
	var amount: int = fuzzer.next_value()

	enemy.take_damage(amount, BaseEnemy.DamageType.STOMP)

	assert_bool(enemy.is_queued_for_deletion()).is_false()
	assert_bool(enemy.has_armor).is_true()
	assert_int(enemy.hp).is_equal(1)


## Propiedad: sin armadura, cualquier daño >= hp mata, por cualquier vía.
func test_unarmored_enemy_dies_to_any_lethal_amount(
	fuzzer := Fuzzers.rangei(1, 1000), fuzzer_iterations := 100
) -> void:
	var enemy := _spawn_enemy(false)
	var amount: int = fuzzer.next_value()
	var type: int = (
		BaseEnemy.DamageType.MELEE if amount % 2 == 0 else BaseEnemy.DamageType.STOMP
	)

	enemy.take_damage(amount, type)

	assert_bool(enemy.is_queued_for_deletion()).is_true()
