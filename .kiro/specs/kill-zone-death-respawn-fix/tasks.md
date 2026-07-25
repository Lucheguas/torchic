# Implementation Plan

## Overview

Fix del bug de muerte/respawn en el vacío de `floor_1`, con dos causas independientes: el pipeline
de muerte queda desarmado con boot F6 (`player_ref == null`, `CheckpointSystem` sin inicializar) y
la cobertura de vacío de la escena está incompleta (dos huecos entre pilares, dos `KillZone`
inalcanzables y un `CollisionShape2D` anidado que Godot ignora). Se suma la corrección de
`map_length_px` de floor 1 en el registry.

El plan sigue el flujo exploratorio: primero los tests que **fallan** sobre el código sin fix
(tareas 1–4) para confirmar las causas con contraejemplos concretos, después los tests de
preservación que **pasan** sobre el código sin fix (tarea 5) para fijar la línea base, y solo
entonces la implementación (tarea 6) con re-ejecución de los mismos tests.

Lenguaje: **GDScript (Godot 4.7)**, tabs, type hints. Tests con **GdUnit4** en `test/level_system/`,
fuzzers con ≥100 iteraciones únicamente donde hay matemática pura (cobertura geométrica y progreso).

Archivos de test previstos:

- `test/level_system/test_level_manager_death_pipeline.gd` — pipeline de muerte (escena en el árbol)
- `test/level_system/test_floor_1_kill_zone_coverage.gd` — geometría de `floor_1.tscn` (pura) + smoke test
- `test/level_system/test_checkpoint_progress.gd` — `calculate_progress()` (aritmética pura)

## Tasks

- [ ] 1. Escribir test de exploración de la condición de bug (pipeline de muerte)
  - **Property 1: Bug Condition** - Morir en el vacío devuelve al respawn correcto
  - **CRITICAL**: este test DEBE FALLAR sobre el código sin fix — la falla confirma que el bug existe
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: este test codifica el comportamiento esperado; cuando pase tras la implementación, valida el fix
  - **GOAL**: obtener contraejemplos concretos de la causa A (`player_ref == null` con boot F6)
  - **Scoped PBT Approach**: bug determinista → acotar la propiedad a los contraejemplos concretos del diseño en vez de fuzzear el pipeline completo
  - Archivo: `test/level_system/test_level_manager_death_pipeline.gd`
  - Simular boot F6: instanciar `scenes/levels/floor_1.tscn` a mano en el árbol de test (sin pasar por `SceneLoader`), esperar un frame de física
  - Colocar al jugador en los contraejemplos de `isBugCondition(X)` (vacío alcanzable: `y > 641`, `x ∈ [0, 5446]`): `(2170, 710)`, `(4550, 700)`, `(4850, 700)`
  - Invocar `LevelManager.handle_player_death()` y afirmar la Property 1 del diseño: `player_ref != null`, `player.global_position == checkpoint_system.get_respawn_position()`, `player.velocity == Vector2.ZERO`, `current_state == PLAYING_MAIN_LEVEL`, `player.global_position.y <= 641`
  - Ejecutar sobre el código SIN FIX
  - **EXPECTED OUTCOME**: el test FALLA (correcto — prueba que el bug existe)
  - Documentar los contraejemplos: `player_ref` nulo con boot F6 y `handle_player_death()` retornando en silencio sin mover al jugador
  - Marcar la tarea completa cuando el test esté escrito, ejecutado y la falla documentada
  - _Requirements: 1.1, 2.1, 2.3, 2.4_

- [ ] 2. Escribir test de exploración de cobertura del vacío en `floor_1` (geometría pura)
  - **Property 3: Bug Condition** - Cobertura total del vacío en `floor_1`
  - **CRITICAL**: este test DEBE FALLAR sobre la escena sin fix
  - **DO NOT attempt to fix the test or the scene when it fails**
  - Archivo: `test/level_system/test_floor_1_kill_zone_coverage.gd`
  - Propiedad pura: cargar `floor_1.tscn`, recorrer el árbol y calcular el rect global de cada `CollisionShape2D` que sea **hijo directo** de un `Area2D` con script `KillZone`
  - **PBT con fuzzer de GdUnit4**: fuzzear `x ∈ [0, 5446]` con ≥100 iteraciones; para cada `x` afirmar que existe un shape hijo directo cuyo rect cubre ese `x` y cuyo `top > 641` (`LOWEST_WALKABLE_Y`)
  - Test adicional (determinista): ningún `CollisionShape2D` de una `KillZone` tiene como padre otro `CollisionShape2D`
  - Test adicional (determinista): ninguna `KillZone` queda por debajo del rect sólido de `Ground_Zone3` (inalcanzable)
  - Ejecutar sobre la escena SIN FIX
  - **EXPECTED OUTCOME**: el test FALLA con contraejemplos en `x ∈ [4466, 4626]` (hueco `Pillar1`→`Pillar2`) y `x ∈ [4766, 4926]` (hueco `Pillar2`→`Pillar3`), más el shape anidado `KillZone/CollisionShape2D/CollisionShape2D` y las `KillZone_Bridge1/2` inalcanzables
  - Documentar los contraejemplos que devuelva el fuzzer
  - _Requirements: 1.3, 1.4, 1.5, 1.6, 2.5, 2.6_

- [ ] 3. Escribir test de exploración de respawn en el origen del mundo
  - **Property 4: Bug Condition** - Nunca se respawnea en el origen del mundo
  - **CRITICAL**: este test DEBE FALLAR sobre el código sin fix
  - **DO NOT attempt to fix the test or the code when it fails**
  - Archivo: `test/level_system/test_level_manager_death_pipeline.gd`
  - Simular boot F6 sin haber tocado ningún `CheckpointMarker` (`reached_cp == NONE`)
  - Afirmar que tras la muerte el jugador queda en el spawn del jugador de la escena (≈ `(100, 570)`) y **nunca** en `Vector2.ZERO`
  - Ejecutar sobre el código SIN FIX
  - **EXPECTED OUTCOME**: el test FALLA — `checkpoint_system.level_start_position == Vector2.ZERO` porque `initialize_for_level()` nunca se llamó
  - Documentar el contraejemplo
  - _Requirements: 1.2, 2.2_

- [ ] 4. Escribir test de exploración del progreso del nivel (aritmética pura)
  - **Property 5: Bug Condition** - El progreso del nivel no satura antes de la meta
  - **CRITICAL**: este test DEBE FALLAR sobre el registry sin fix
  - **DO NOT attempt to fix the test or the resource when it fails**
  - Archivo: `test/level_system/test_checkpoint_progress.gd`
  - **PBT con fuzzer de GdUnit4**: fuzzear `x ∈ [0, 5446]` con ≥100 iteraciones sobre un `CheckpointSystem` inicializado con el `map_length_px` de floor 1 leído de `resources/level_registry.tres`
  - Afirmar `calculate_progress(x) == x / 5450.0` (con tolerancia de float) y `calculate_progress(x) < 1.0`
  - Ejecutar sobre el registry SIN FIX
  - **EXPECTED OUTCOME**: el test FALLA — `calculate_progress(3000) == 1.0` saturado porque `map_length_px = 2700`
  - Documentar el contraejemplo del fuzzer
  - _Requirements: 1.7, 2.7_

- [ ] 5. Escribir tests de preservación (ANTES de implementar el fix)
  - **Property 2: Preservation** - Entradas fuera de la condición de bug
  - **IMPORTANT**: seguir la metodología de observación primero — correr el código SIN FIX, registrar el comportamiento real y fijarlo en los tests
  - Observar sobre el código SIN FIX y anotar los valores obtenidos:
    - Boot F5 (`start_game()` → `SceneLoader` → `_on_scene_loaded()`), muerte en el pit cubierto `x ∈ [2099, 2246]`: posición de respawn resultante, `velocity`, `current_state`
    - Boot F5, muerte en el pit cubierto `x ∈ [4146, 4326]`: ídem
    - Jugador con `y <= 641` (apoyado en suelo o plataforma): `handle_player_death()` no se dispara y la posición no cambia
    - Muerte por contacto con enemigo (`MovementController._check_enemy_contact_damage()`): respawn, `velocity == Vector2.ZERO`, estado final `PLAYING_MAIN_LEVEL`
    - `CheckpointMarker`: se activa una sola vez y fija el respawn vía `set_reached_checkpoint()`
    - Boot F5: `initialize_for_level()` se llamó exactamente una vez y `_current_scene_root` proviene de `SceneLoader`
    - `KillZone` con cuerpo fuera del grupo `player`: ignorado; sin autoload `LevelManager`: `push_error` sin crash
  - Escribir tests que fijen ese comportamiento observado (`test_level_manager_death_pipeline.gd` para pipeline, `test_floor_1_kill_zone_coverage.gd` para geometría)
  - **PBT con fuzzer de GdUnit4** (≥100 iteraciones): fuzzear posiciones con `y <= 641` dentro de la envolvente del nivel (`x ∈ [0, 5446]`) y afirmar que ninguna cae dentro del rect de ninguna `KillZone` viva — cubre en particular la franja `y ∈ (641, 668]` que el suelo del mundo no dispara
  - Ejecutar sobre el código SIN FIX
  - **EXPECTED OUTCOME**: los tests PASAN (fijan la línea base a preservar)
  - Marcar la tarea completa cuando los tests estén escritos, ejecutados y pasando sobre el código sin fix
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [ ] 6. Fix de muerte y respawn en el vacío de `floor_1`

  - [ ] 6.1 Armar el pipeline de muerte con boot standalone en `level_manager.gd`
    - Extraer `_wire_level_nodes(root: Node)` con el bloque que hoy vive inline en `_on_scene_loaded()`: conexión de `TransitionTrigger` con `target_type == 2` y registro/conexión de los `CheckpointMarker` (`marker_activated` → `_on_checkpoint_marker_reached`)
    - Llamar `_wire_level_nodes()` desde `_on_scene_loaded()` (comportamiento F5 idéntico) — la extracción se justifica porque a partir de este fix hay dos llamadores reales
    - Agregar `_bootstrap_standalone_scene()`: corta si `_current_scene_root != null`; retorna sin ruido si no hay nodo en el grupo `player`; si lo hay, asigna `_current_scene_root = get_tree().current_scene`, llama `_setup_player_and_camera()`, `checkpoint_system.initialize_for_level(player_ref.global_position, 0.0, config.map_length_px)`, `_wire_level_nodes(_current_scene_root)`, `current_state = PLAYING_MAIN_LEVEL` y emite `floor_started`
    - Disparo one-shot al final de `_ready()`: `_bootstrap_standalone_scene.call_deferred()` — el bootstrap corre al arrancar, no de forma perezosa en la muerte, para que `initialize_for_level()` capture la posición inicial del jugador y no la de caída
    - `handle_player_death()` deja de fallar en silencio: `push_error` cuando `player_ref` es nulo, sin nuevos flags ni estados
    - _Bug_Condition: `isBugCondition(X)` rama A — `inReachableVoid(X) AND NOT deathPipelineArmed(X)`_
    - _Expected_Behavior: Property 1 y Property 4 del diseño — `player_ref != null`, respawn en `get_respawn_position()`, `velocity == Vector2.ZERO`, `PLAYING_MAIN_LEVEL`, nunca `Vector2.ZERO`_
    - _Preservation: Preservation Requirements del diseño — el bootstrap no corre cuando el manager sí cargó la escena (3.5); pipeline de muerte por enemigo intacto (3.6)_
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.5, 3.6_

  - [ ] 6.2 Reemplazar las `KillZone` de `floor_1.tscn` por un único suelo del mundo
    - Borrar `KillZone` (con su shape hijo y el shape anidado `KillZone/CollisionShape2D/CollisionShape2D`), `KillZone_Bridge1`, `KillZone_Bridge2` y `KillZone_Bridge3` (con su shape `morir`)
    - Borrar los `SubResource` que quedan sin uso (`kill_zone_shape`, `pit_bridge_shape`) y ajustar `load_steps` de la escena
    - Agregar un único `Area2D` `KillZone_WorldFloor` con `script = res://scripts/kill_zone.gd` y `position = Vector2(2750, 700)`
    - Agregar un `CollisionShape2D` **hijo directo** del `Area2D` (sin offset) con `RectangleShape2D` de `size = Vector2(5700, 64)` → rect global `x ∈ [-100, 5600]`, `y ∈ [668, 732]`
    - No tocar `scripts/kill_zone.gd`: su lógica (grupo `player`, `push_error` sin autoload, delegación a `handle_player_death()`) ya es correcta
    - _Bug_Condition: `isBugCondition(X)` rama B — `inReachableVoid(X) AND NOT coveredByLiveKillZone(X)`_
    - _Expected_Behavior: Property 3 del diseño — todo `x ∈ [0, 5446]` cubierto por un shape hijo directo con `top > 641`, y ningún shape anidado_
    - _Preservation: Preservation Requirements del diseño — muertes ya funcionales en los pits `x ∈ [2099, 2246]` y `x ∈ [4146, 4326]` con la misma posición de respawn (3.2, 3.3); nada se dispara con `y <= 641` (3.1)_
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3_

  - [ ] 6.3 Corregir `map_length_px` de floor 1 en el registry
    - En `resources/level_registry.tres`, `SubResource("LevelConfig_1")`: `map_length_px = 2700.0` → `5450.0`
    - No tocar los configs de floor 2 ni floor 5
    - _Bug_Condition: `calculate_progress(x)` saturado en 1.0 desde `x = 2700`_
    - _Expected_Behavior: Property 5 del diseño — `calculate_progress(x) == x / 5450.0` y `< 1.0` para todo `x ∈ [0, 5446]`_
    - _Preservation: `load_floor()` sigue cayendo a piso 1 sin config (3.9)_
    - _Requirements: 1.7, 2.7, 3.9_

  - [ ] 6.4 Verificar que los tests de exploración del pipeline ahora pasan
    - **Property 1: Expected Behavior** - Morir en el vacío devuelve al respawn correcto
    - **Property 4: Expected Behavior** - Nunca se respawnea en el origen del mundo
    - **IMPORTANT**: re-ejecutar los MISMOS tests de las tareas 1 y 3 — no escribir tests nuevos
    - Ejecutar `test/level_system/test_level_manager_death_pipeline.gd`
    - **EXPECTED OUTCOME**: los tests PASAN (confirman que la causa A está resuelta)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 6.5 Verificar que los tests de exploración de geometría y progreso ahora pasan
    - **Property 3: Expected Behavior** - Cobertura total del vacío en `floor_1`
    - **Property 5: Expected Behavior** - El progreso del nivel no satura antes de la meta
    - **IMPORTANT**: re-ejecutar los MISMOS tests de las tareas 2 y 4 — no escribir tests nuevos
    - Ejecutar `test/level_system/test_floor_1_kill_zone_coverage.gd` y `test/level_system/test_checkpoint_progress.gd` (fuzzers con ≥100 iteraciones)
    - **EXPECTED OUTCOME**: los tests PASAN (confirman que la causa B y el `map_length_px` están resueltos)
    - _Requirements: 2.5, 2.6, 2.7_

  - [ ] 6.6 Verificar que los tests de preservación siguen pasando
    - **Property 2: Preservation** - Entradas fuera de la condición de bug
    - **IMPORTANT**: re-ejecutar los MISMOS tests de la tarea 5 — no escribir tests nuevos
    - Ejecutar los tests de preservación, incluido el fuzzer de posiciones con `y <= 641`
    - **EXPECTED OUTCOME**: los tests PASAN (sin regresiones)
    - Confirmar que la posición de respawn en los pits ya cubiertos es idéntica a la observada antes del fix
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9_

  - [ ] 6.7 Smoke test de `floor_1.tscn` tras el refactor
    - En `test/level_system/test_floor_1_kill_zone_coverage.gd`: cargar e instanciar `res://scenes/levels/floor_1.tscn` y afirmar que instancia sin errores
    - Afirmar que la escena contiene exactamente una `KillZone` (`KillZone_WorldFloor`) con su `CollisionShape2D` como hijo directo
    - _Requirements: 2.5, 2.6_

- [ ] 7. Checkpoint - Ensure all tests pass
  - Ejecutar la suite completa de GdUnit4 en `test/`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Las tareas 1–4 son tests de exploración: **deben fallar** sobre el código sin fix. Esa falla es
  el resultado esperado y confirma la hipótesis de causa raíz; no se corrige nada en ese momento.
- La tarea 5 es preservación: **debe pasar** sobre el código sin fix. Se escribe observando el
  comportamiento real, no el asumido.
- Si algún test de exploración pasa sobre el código sin fix, la hipótesis de causa raíz está mal:
  re-analizar antes de implementar.
- Los fuzzers (≥100 iteraciones) se usan solo en las tres propiedades genuinamente puras: cobertura
  geométrica sobre `x`, progreso aritmético sobre `x`, y ausencia de solape del suelo del mundo con
  posiciones `y <= 641`. El pipeline de muerte se prueba con los contraejemplos concretos del diseño.
- El smoke test de `floor_1.tscn` (6.7) es obligatorio por el steering: cualquier refactor de escena
  debe validar que la escena instancia sin errores.
- Fuera de alcance (specs aparte): cablear `CheckpointSystem.update_checkpoints()`, aplicar el mismo
  patrón a `floor_2`, y resetear el estado del nivel al respawnear.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4"] },
    { "id": 1, "tasks": ["5"] },
    { "id": 2, "tasks": ["6.1", "6.2", "6.3"] },
    { "id": 3, "tasks": ["6.4", "6.5", "6.6", "6.7"] },
    { "id": 4, "tasks": ["7"] }
  ]
}
```
