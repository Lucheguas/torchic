# GdUnit4 test suite
extends GdUnitTestSuite

## Regla de contacto enemigo->jugador: un choque lateral/inferior (normal casi
## horizontal) mata; un choque casi vertical es un pisotón (el jugador cayó
## encima) y lo gestiona StompArea, no la muerte por contacto.


func test_horizontal_contact_is_lethal() -> void:
	# Enemigo caminando de frente contra el jugador: normal ~horizontal.
	assert_bool(EnemyBasic.is_side_contact(0.0)).is_true()
	assert_bool(EnemyBasic.is_side_contact(0.3)).is_true()
	assert_bool(EnemyBasic.is_side_contact(-0.3)).is_true()


func test_vertical_contact_is_not_lethal() -> void:
	# Jugador encima del enemigo (pisotón): normal casi vertical.
	assert_bool(EnemyBasic.is_side_contact(1.0)).is_false()
	assert_bool(EnemyBasic.is_side_contact(-1.0)).is_false()
	assert_bool(EnemyBasic.is_side_contact(0.9)).is_false()


## Propiedad: la clasificación es simétrica respecto al signo de la normal
## (izquierda/derecha, arriba/abajo dan el mismo veredicto por magnitud).
func test_classification_is_symmetric(
	fuzzer := Fuzzers.rangef(-1.0, 1.0), fuzzer_iterations := 100
) -> void:
	var ny: float = fuzzer.next_value()
	assert_bool(EnemyBasic.is_side_contact(ny)).is_equal(
		EnemyBasic.is_side_contact(-ny)
	)
