# GdUnit4 test suite
extends GdUnitTestSuite

## Property 5: Bug Condition - El progreso del nivel no satura antes de la meta.
##
## Aritmética pura sobre `CheckpointSystem.calculate_progress()` con el
## `map_length_px` de floor 1 leído de `resources/level_registry.tres`.
##
## Sobre el registry SIN FIX estos tests DEBEN FALLAR: `map_length_px = 2700`
## mientras el nivel llega a x = 5446, así que el progreso satura en 1.0 desde
## x = 2700. No corregir el test ni el recurso: la falla es la evidencia del bug.
##
## **Validates: Requirements 1.7, 2.7**

const REGISTRY_PATH := "res://resources/level_registry.tres"
const FLOOR_1_ID := 1
## Extensión real de floor 1: `Ground_Meta` termina en x = 5446.
const LEVEL_MIN_X := 0
const LEVEL_MAX_X := 5446
## Valor esperado de `map_length_px` para floor 1 (requirement 2.7).
const EXPECTED_MAP_LENGTH_PX := 5450.0
const PROGRESS_EPSILON := 0.0001

var _checkpoint_system: CheckpointSystem
var _map_length_px: float


func before_test() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH)
	var config: LevelConfigData = registry.get_level_config(FLOOR_1_ID)
	_map_length_px = config.map_length_px
	_checkpoint_system = auto_free(CheckpointSystem.new())
	_checkpoint_system.initialize_for_level(Vector2.ZERO, 0.0, _map_length_px)


## PBT: para todo x en [0, 5446] el progreso debe ser x / 5450 y nunca saturar.
func test_progress_never_saturates_before_the_goal(
	fuzzer := Fuzzers.rangei(LEVEL_MIN_X, LEVEL_MAX_X), fuzzer_iterations := 100
) -> void:
	var player_x := float(fuzzer.next_value())
	var progress := _checkpoint_system.calculate_progress(player_x)
	assert_float(progress).is_equal_approx(player_x / EXPECTED_MAP_LENGTH_PX, PROGRESS_EPSILON)
	assert_float(progress).is_less(1.0)


## Contraejemplo concreto documentado en el diseño: x = 3000 debería dar ≈ 0.55.
func test_progress_at_x_3000_is_not_saturated() -> void:
	var progress := _checkpoint_system.calculate_progress(3000.0)
	assert_float(progress).is_equal_approx(3000.0 / EXPECTED_MAP_LENGTH_PX, PROGRESS_EPSILON)
	assert_float(progress).is_less(1.0)
