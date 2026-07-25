# GdUnit4 test suite
extends GdUnitTestSuite

## Property 1: Bug Condition - Morir en el vacío devuelve al respawn correcto.
##
## Simula boot F6: `scenes/levels/floor_1.tscn` se instancia a mano en el árbol
## de test, sin pasar por `SceneLoader`, así que el autoload `LevelManager`
## existe pero nunca cargó el piso (`player_ref == null`).
##
## Sobre el código SIN FIX estos tests DEBEN FALLAR: `handle_player_death()`
## retorna en silencio y el jugador se queda en la posición de caída. No
## corregir el test ni el código: la falla es la evidencia del bug.
##
## **Validates: Requirements 1.1, 2.1, 2.3, 2.4**

const FLOOR_1_PATH := "res://scenes/levels/floor_1.tscn"
## Cota más baja transitable de floor 1 (base de los pilares).
const LOWEST_WALKABLE_Y := 641.0

var _floor: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	# Boot F6: la escena entra al árbol por su cuenta, el LevelManager no la carga.
	var packed: PackedScene = load(FLOOR_1_PATH)
	_floor = auto_free(packed.instantiate()) as Node2D
	add_child(_floor)
	await await_millis(50)
	_player = _floor.get_node("Player") as CharacterBody2D
	# El jugador se posiciona a mano en cada test; la física no debe reubicarlo.
	_player.set_physics_process(false)


func after_test() -> void:
	# El autoload sobrevive entre tests: devolverlo al estado de arranque.
	LevelManager.player_ref = null
	LevelManager._current_scene_root = null
	LevelManager.current_state = LevelManager.GameFlowState.LOADING


## Property 1 sobre el contraejemplo del pit ya cubierto (rama A del bug).
func test_death_in_covered_pit_respawns_player_with_f6_boot() -> void:
	await _assert_death_respawns_player(Vector2(2170, 710))


## Property 1 sobre el hueco `Pillar1` → `Pillar2` (ramas A y B del bug).
func test_death_between_pillar_1_and_2_respawns_player() -> void:
	await _assert_death_respawns_player(Vector2(4550, 700))


## Property 1 sobre el hueco `Pillar2` → `Pillar3` (ramas A y B del bug).
func test_death_between_pillar_2_and_3_respawns_player() -> void:
	await _assert_death_respawns_player(Vector2(4850, 700))


# --- Helpers ---

## Coloca al jugador en un punto de vacío alcanzable (`isBugCondition(X)`),
## invoca el pipeline de muerte y afirma la Property 1 completa.
func _assert_death_respawns_player(void_position: Vector2) -> void:
	_player.global_position = void_position
	_player.velocity = Vector2(0.0, 900.0)

	LevelManager.handle_player_death()
	await await_millis(50)

	assert_object(LevelManager.player_ref).is_not_null()
	var respawn: Vector2 = LevelManager.checkpoint_system.get_respawn_position()
	assert_vector(_player.global_position).is_equal(respawn)
	assert_vector(_player.velocity).is_equal(Vector2.ZERO)
	assert_int(LevelManager.current_state).is_equal(
		LevelManager.GameFlowState.PLAYING_MAIN_LEVEL
	)
	assert_float(_player.global_position.y).is_less_equal(LOWEST_WALKABLE_Y)
