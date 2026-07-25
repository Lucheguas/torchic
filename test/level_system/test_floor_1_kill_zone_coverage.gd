# GdUnit4 test suite
extends GdUnitTestSuite

## Property 3: Bug Condition - Cobertura total del vacío en `floor_1`.
##
## Propiedad pura: cargar `floor_1.tscn`, recorrer el árbol y calcular el rect
## global de cada `CollisionShape2D` que sea HIJO DIRECTO de un `Area2D` con
## script `KillZone` ("KillZone viva"). Godot solo agrega al `CollisionObject2D`
## los shapes hijos directos; los anidados bajo otro shape no participan.
##
## Sobre la escena SIN FIX estos tests DEBEN FALLAR: hay huecos entre pilares
## sin cobertura (`x ∈ [4466, 4626]` y `x ∈ [4766, 4926]`), un shape anidado
## `KillZone/CollisionShape2D/CollisionShape2D` que Godot ignora, y dos
## `KillZone_Bridge1/2` por debajo del suelo sólido de `Ground_Zone3`. No
## corregir el test ni la escena: la falla es la evidencia del bug.
##
## **Validates: Requirements 1.3, 1.4, 1.5, 1.6, 2.5, 2.6**

const FLOOR_1_PATH := "res://scenes/levels/floor_1.tscn"
## Cota más baja transitable de floor 1 (base de los pilares).
const LOWEST_WALKABLE_Y := 641.0
## Extensión horizontal real del nivel (`Ground_Meta` termina en x = 5446).
const LEVEL_MIN_X := 0
const LEVEL_MAX_X := 5446

var _floor: Node2D
## KillZone vivas presentes en la escena.
var _kill_zones: Array[KillZone]
## Rects globales de los shapes hijos directos de cada KillZone viva.
var _live_shapes: Array[Rect2]


func before_test() -> void:
	var packed: PackedScene = load(FLOOR_1_PATH)
	_floor = auto_free(packed.instantiate()) as Node2D
	add_child(_floor)
	# Un frame para que las transformadas globales queden resueltas en el árbol.
	await await_millis(50)

	_kill_zones = []
	_live_shapes = []
	for node in _all_descendants(_floor):
		if _is_kill_zone(node):
			_kill_zones.append(node as KillZone)
	for kz in _kill_zones:
		for shape in _direct_child_shapes(kz):
			_live_shapes.append(_global_rect(shape))


# --- Property 3 (PBT): cobertura total del vacío ---

## PBT: para todo x en [0, 5446] existe un shape hijo directo de una KillZone
## cuyo rect global cubre ese x y cuyo borde superior está por debajo de y = 641.
func test_void_is_fully_covered_by_live_kill_zones(
	fuzzer := Fuzzers.rangei(LEVEL_MIN_X, LEVEL_MAX_X), fuzzer_iterations := 100
) -> void:
	var player_x := float(fuzzer.next_value())
	assert_bool(_x_covered_below_walkable(player_x)).override_failure_message(
		"x = %.1f no está cubierto por ninguna KillZone viva con top > %.0f" % [
			player_x, LOWEST_WALKABLE_Y
		]
	).is_true()


# --- Deterministas ---

## Ningún `CollisionShape2D` de una KillZone tiene como padre otro
## `CollisionShape2D` (los shapes anidados son ignorados por Godot).
func test_no_kill_zone_shape_is_nested_under_another_shape() -> void:
	var nested: Array[String] = []
	for kz in _kill_zones:
		for node in _all_descendants(kz):
			if node is CollisionShape2D and node.get_parent() is CollisionShape2D:
				nested.append(str(_floor.get_path_to(node)))
	assert_array(nested).override_failure_message(
		"Shapes anidados bajo otro shape (ignorados por Godot): %s" % str(nested)
	).is_empty()


## Ninguna KillZone queda por debajo del rect sólido de `Ground_Zone3`
## (inalcanzable: el jugador nunca puede atravesar el suelo para tocarla).
func test_no_kill_zone_is_below_solid_ground_zone3() -> void:
	var ground_rect := _global_rect(
		_floor.get_node("Environment/Ground_Zone3/CollisionShape2D") as CollisionShape2D
	)
	var ground_bottom := ground_rect.position.y + ground_rect.size.y
	var ground_left := ground_rect.position.x
	var ground_right := ground_rect.position.x + ground_rect.size.x

	var unreachable: Array[String] = []
	for kz in _kill_zones:
		for shape in _direct_child_shapes(kz):
			var rect := _global_rect(shape)
			# Inalcanzable = totalmente sombreada: todo su ancho cae bajo el suelo
			# sólido, así que ningún x suyo es accesible. Una zona que se extiende
			# más allá del suelo (hacia un pozo abierto) sí es alcanzable.
			var fully_shadowed_x := rect.position.x >= ground_left \
				and rect.position.x + rect.size.x <= ground_right
			if rect.position.y >= ground_bottom and fully_shadowed_x:
				unreachable.append(str(_floor.get_path_to(kz)))
	assert_array(unreachable).override_failure_message(
		"KillZone inalcanzables (debajo del suelo sólido de Ground_Zone3): %s" % str(unreachable)
	).is_empty()


# --- Helpers ---

## `Area2D` con script `KillZone` (detección por ruta de script, robusta).
func _is_kill_zone(node: Node) -> bool:
	if not (node is Area2D):
		return false
	var scr: Script = node.get_script()
	return scr != null and scr.resource_path.ends_with("kill_zone.gd")


## Recorrido en profundidad de todos los descendientes de `node`.
func _all_descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out


## `CollisionShape2D` con `RectangleShape2D` que son hijos DIRECTOS del Area2D.
func _direct_child_shapes(kill_zone: KillZone) -> Array[CollisionShape2D]:
	var out: Array[CollisionShape2D] = []
	for child in kill_zone.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			out.append(child as CollisionShape2D)
	return out


## Rect global de un `CollisionShape2D` rectangular (sin rotación ni escala).
func _global_rect(shape_node: CollisionShape2D) -> Rect2:
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size
	var center: Vector2 = shape_node.global_position
	return Rect2(center - size * 0.5, size)


## True si algún shape vivo cubre `x` y su borde superior está por debajo de y = 641.
func _x_covered_below_walkable(x: float) -> bool:
	for rect in _live_shapes:
		var covers_x := rect.position.x <= x and x <= rect.position.x + rect.size.x
		if covers_x and rect.position.y > LOWEST_WALKABLE_Y:
			return true
	return false
