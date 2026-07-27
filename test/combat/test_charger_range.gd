# GdUnit4 test suite
extends GdUnitTestSuite

## Clasificación de distancia del EnemyCharger: fuera de rango no reacciona,
## corta distancia => golpe (MELEE), media/larga => embestida (CHARGE).

const MELEE := 40.0
const DETECTION := 160.0


func test_out_of_range_is_none() -> void:
	assert_int(EnemyCharger.classify_range(200.0, MELEE, DETECTION)).is_equal(EnemyCharger.RangeBand.NONE)


func test_close_is_melee() -> void:
	assert_int(EnemyCharger.classify_range(10.0, MELEE, DETECTION)).is_equal(EnemyCharger.RangeBand.MELEE)
	# Justo en el borde de melee sigue siendo golpe.
	assert_int(EnemyCharger.classify_range(MELEE, MELEE, DETECTION)).is_equal(EnemyCharger.RangeBand.MELEE)


func test_mid_is_charge() -> void:
	assert_int(EnemyCharger.classify_range(100.0, MELEE, DETECTION)).is_equal(EnemyCharger.RangeBand.CHARGE)
	# Justo dentro del rango de detección todavía embiste.
	assert_int(EnemyCharger.classify_range(DETECTION, MELEE, DETECTION)).is_equal(EnemyCharger.RangeBand.CHARGE)


## Propiedad: cualquier distancia dentro de detección es MELEE o CHARGE (nunca
## NONE), y cruza a NONE en cuanto supera la detección.
func test_range_bands_are_exhaustive(
	fuzzer := Fuzzers.rangef(0.0, DETECTION), fuzzer_iterations := 100
) -> void:
	var dist: float = fuzzer.next_value()
	var result := EnemyCharger.classify_range(dist, MELEE, DETECTION)
	assert_bool(result == EnemyCharger.RangeBand.MELEE or result == EnemyCharger.RangeBand.CHARGE).is_true()
