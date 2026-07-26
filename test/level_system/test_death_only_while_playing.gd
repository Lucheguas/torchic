# GdUnit4 test suite
extends GdUnitTestSuite

## handle_player_death() solo actúa mientras el jugador tiene el control.
## Durante LOADING, transiciones, ENTRE_NIVEL o el propio RESPAWNING el flujo
## está reposicionando al jugador; una muerte aceptada ahí lo teletransportaría
## al checkpoint a media transición.

const FLOOR_1_PATH := "res://scenes/levels/floor_1.tscn"
const VOID_POSITION := Vector2(2170, 710)

var _floor: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	var packed: PackedScene = load(FLOOR_1_PATH)
	_floor = auto_free(packed.instantiate()) as Node2D
	add_child(_floor)
	await await_millis(50)
	_player = _floor.get_node("Player") as CharacterBody2D
	_player.set_physics_process(false)


func after_test() -> void:
	LevelManager.player_ref = null
	LevelManager._current_scene_root = null
	LevelManager.current_state = LevelManager.GameFlowState.LOADING


func test_death_is_ignored_while_loading() -> void:
	_assert_death_ignored_in_state(LevelManager.GameFlowState.LOADING)


func test_death_is_ignored_during_entre_nivel() -> void:
	_assert_death_ignored_in_state(LevelManager.GameFlowState.ENTRE_NIVEL)


func test_death_is_ignored_while_already_respawning() -> void:
	_assert_death_ignored_in_state(LevelManager.GameFlowState.RESPAWNING)


## El caso de control: jugando, la muerte sí se procesa.
func test_death_is_processed_while_playing_main_level() -> void:
	LevelManager.current_state = LevelManager.GameFlowState.PLAYING_MAIN_LEVEL
	_player.global_position = VOID_POSITION

	LevelManager.handle_player_death()

	assert_vector(_player.global_position).is_not_equal(VOID_POSITION)


func _assert_death_ignored_in_state(state: int) -> void:
	LevelManager.current_state = state
	_player.global_position = VOID_POSITION

	LevelManager.handle_player_death()

	assert_vector(_player.global_position).is_equal(VOID_POSITION)
	assert_int(LevelManager.current_state).is_equal(state)
