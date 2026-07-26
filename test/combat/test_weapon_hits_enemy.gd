# GdUnit4 test suite
extends GdUnitTestSuite

## Camino REAL del arma: hitbox Area2D (MeleeAttack) -> body_entered ->
## BaseEnemy.take_damage. A diferencia de test_damage_matrix, aquí NO se llama a
## take_damage a mano: se dispara el arma y se comprueba que la detección de
## colisión alcanza al enemigo. Cubre capas de colisión, activación de
## `monitoring` y solape preexistente al iniciar el swing.

const PLAYER_PATH := "res://scenes/player.tscn"
const ENEMY_PATH := "res://scenes/enemy_basic.tscn"

var _player: CharacterBody2D
var _melee: MeleeAttack
var _enemy: EnemyBasic


func before_test() -> void:
	_player = auto_free(load(PLAYER_PATH).instantiate()) as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2(0, 0)
	# Quieto: sin gravedad ni input; el arma (nodo aparte) sigue tickeando.
	_player.set_physics_process(false)
	_melee = _player.get_node("MeleeAttack") as MeleeAttack


func after_test() -> void:
	if is_instance_valid(_enemy):
		_enemy.queue_free()


## Coloca al enemigo dentro del alcance frontal y lo devuelve.
func _spawn_enemy_in_reach(armored: bool) -> EnemyBasic:
	var enemy: EnemyBasic = load(ENEMY_PATH).instantiate() as EnemyBasic
	enemy.has_armor = armored
	add_child(enemy)
	enemy.global_position = _player.global_position + Vector2(_melee.attack_offset, 0)
	enemy.set_physics_process(false)  # no patrulla ni cae durante la prueba
	return enemy


func test_weapon_kills_unarmored_enemy_via_hitbox() -> void:
	_enemy = _spawn_enemy_in_reach(false)

	_melee.trigger(1.0)  # mira a la derecha, hacia el enemigo
	await await_millis(80)

	# El enemigo sin armadura muere: queue_free lo libera del árbol.
	assert_bool(is_instance_valid(_enemy)).override_failure_message(
		"El arma no alcanzó al enemigo sin armadura vía la hitbox Area2D."
	).is_false()


func test_weapon_breaks_armor_via_hitbox_without_killing() -> void:
	_enemy = _spawn_enemy_in_reach(true)

	_melee.trigger(1.0)
	await await_millis(80)

	assert_bool(_enemy.is_queued_for_deletion()).is_false()
	assert_bool(_enemy.has_armor).is_false()


## Un solo swing no debe golpear dos veces al mismo enemigo (mataría a un
## blindado de un golpe en vez de solo romperle la armadura).
func test_single_swing_hits_each_enemy_once() -> void:
	_enemy = _spawn_enemy_in_reach(true)

	_melee.trigger(1.0)
	await await_millis(200)  # cubre toda la duración del swing

	# Sigue vivo con la armadura rota: exactamente un impacto.
	assert_bool(_enemy.is_queued_for_deletion()).is_false()
	assert_bool(_enemy.has_armor).is_false()
