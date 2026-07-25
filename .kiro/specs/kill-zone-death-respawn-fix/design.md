# Kill Zone Death Respawn Fix — Diseño del bugfix

## Overview

En `floor_1` el jugador puede caer al vacío sin morir ni volver al checkpoint. El síntoma sale de dos fallos independientes que se suman:

- **A — pipeline de muerte desarmado:** `LevelManager.handle_player_death()` retorna en silencio cuando `player_ref` es `null`. `player_ref` solo se asigna dentro de `_on_scene_loaded()`, es decir únicamente cuando el propio `LevelManager` cargó el piso. Al correr `scenes/levels/floor_1.tscn` directo (F6) el autoload existe pero nunca cargó nada, así que ninguna muerte surte efecto (ni `KillZone`, ni contacto con enemigo) y `CheckpointSystem.level_start_position` queda en `Vector2.ZERO`.
- **B — cobertura de vacío incompleta:** dos huecos entre pilares sin ninguna `KillZone`, dos `KillZone` colocadas debajo de suelo sólido (inalcanzables) y un `CollisionShape2D` anidado dentro de otro shape, que Godot ignora porque no es hijo directo del `Area2D`.

La estrategia del fix es simétrica a las dos causas y deliberadamente pequeña:

1. **Auto-bootstrap del `LevelManager`**: si al arrancar hay un jugador en el árbol que el manager no cargó, resolver `player_ref`, inicializar `CheckpointSystem` y cablear los `CheckpointMarker` una única vez. Además, `handle_player_death()` deja de retornar en silencio: reporta con `push_error`.
2. **Una sola `KillZone` "suelo del mundo"** en `floor_1` que cubre todo el ancho del nivel por debajo de la cota transitable más baja, reemplazando las cuatro `KillZone` actuales (rotas, inalcanzables o parciales).
3. **Corregir `map_length_px` de floor 1** en `resources/level_registry.tres` (2700 → 5450) para que `calculate_progress()` no sature a mitad de nivel.

No se agregan flags, capas de configuración ni abstracciones nuevas: el único código compartido que se extrae es el cableado de nodos del nivel, y solo porque a partir de este fix tiene dos llamadores reales (carga por `SceneLoader` y bootstrap standalone).

## Glossary

- **Bug_Condition (C)**: el jugador entra en vacío alcanzable de `floor_1` y no muere ni respawnea — sea porque el pipeline de muerte está desarmado (`player_ref == null`) o porque ninguna `KillZone` viva cubre esa posición.
- **Property (P)**: tras la muerte el jugador queda exactamente en `CheckpointSystem.get_respawn_position()`, con `velocity == Vector2.ZERO`, estado `PLAYING_MAIN_LEVEL` y por encima de la cota transitable más baja.
- **Preservation**: todo lo que ocurre cuando `¬C(X)` — el jugador no está en vacío, o está en vacío y la muerte ya funcionaba correctamente antes del fix.
- **F / F'**: comportamiento antes del fix (`floor_1.tscn`, `level_manager.gd` y `level_registry.tres` actuales) / después del fix.
- **`handle_player_death()`**: método de `scripts/level_system/level_manager.gd` que hace RESPAWNING → reposicionar → rehabilitar input → volver a `PLAYING_MAIN_LEVEL`. Único punto de muerte del juego (lo invocan `KillZone._on_body_entered()` y `MovementController._check_enemy_contact_damage()`).
- **`player_ref`**: referencia del `LevelManager` al `CharacterBody2D` del jugador. Hoy solo se asigna en `_on_scene_loaded()` vía `_setup_player_and_camera()`.
- **KillZone viva**: `Area2D` con script `KillZone` cuyo `CollisionShape2D` es **hijo directo** del `Area2D`. Los shapes anidados bajo otro shape no participan en la detección de Godot.
- **`LOWEST_WALKABLE_Y = 641`**: cota más baja transitable de `floor_1` (base de `Pillar1/2/3`, `position.y = 617` + medio shape de 48 px).
- **Boot F5 / boot F6**: F5 arranca `scenes/main.tscn` (`game_startup.gd` → `LevelManager.start_game()`); F6 corre `scenes/levels/floor_1.tscn` directamente.

## Bug Details

### Bug Condition

El bug se manifiesta cuando el jugador cae por debajo de toda superficie transitable de `floor_1`, dentro de la extensión horizontal del nivel, y el sistema no lo mata ni lo reposiciona. Eso pasa por dos ramas independientes: el pipeline de muerte está desarmado (`player_ref == null`, boot F6), o la posición del jugador no está cubierta por ninguna `KillZone` viva (boot F5 y F6).

**Especificación formal:**

```
CONST LOWEST_WALKABLE_Y := 641.0
CONST LEVEL_MIN_X       := 0.0
CONST LEVEL_MAX_X       := 5446.0

FUNCTION inReachableVoid(X)
  INPUT: X of type DeathInput { boot_mode, player_pos, reached_cp }
  OUTPUT: boolean

  RETURN X.player_pos.y > LOWEST_WALKABLE_Y
     AND X.player_pos.x >= LEVEL_MIN_X
     AND X.player_pos.x <= LEVEL_MAX_X
END FUNCTION

FUNCTION coveredByLiveKillZone(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  RETURN EXISTS kz IN killZones(floor_1) SUCH THAT
           EXISTS s IN directChildShapes(kz) SUCH THAT
             contains(globalRect(s), X.player_pos)
END FUNCTION

FUNCTION deathPipelineArmed(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  RETURN LevelManager.player_ref != null
END FUNCTION

FUNCTION isBugCondition(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  RETURN inReachableVoid(X)
     AND (NOT deathPipelineArmed(X) OR NOT coveredByLiveKillZone(X))
END FUNCTION
```

### Ejemplos

Geometría verificada leyendo `scenes/levels/floor_1.tscn` (posición del nodo + offset del shape + tamaño del shape):

| Entrada | Rama | Esperado | Actual |
|---|---|---|---|
| F6, `player_pos = (2170, 710)` — pit ya cubierto entre `Ground_Main` y `Ground_AfterPit` | A | respawn en `get_respawn_position()` | `handle_player_death()` retorna en silencio; el jugador sigue cayendo |
| F6, jugador muere sin haber tocado checkpoint | A | respawn en ≈ `(100, 570)` (`PlayerSpawnPoint`) | `level_start_position == Vector2.ZERO` porque nunca se llamó `initialize_for_level()` |
| F5, `player_pos = (4550, 700)` — hueco `Pillar1`→`Pillar2` (x ∈ [4466, 4626]) | B | muerte + respawn | caída infinita: ninguna `KillZone` cubre ese tramo |
| F5, `player_pos = (4850, 700)` — hueco `Pillar2`→`Pillar3` (x ∈ [4766, 4926]) | B | muerte + respawn | caída infinita |
| F5, `player_pos ≈ (4655, 738)` — zona del shape `KillZone/CollisionShape2D/CollisionShape2D` | B | muerte + respawn | shape ignorado por Godot (no es hijo directo del `Area2D`) |
| F5, jugador recorriendo zona 3 (x ∈ [2646, 4146]) | — | `KillZone_Bridge1/2` no deberían existir | nodos muertos a y ≈ 874..908, debajo de `Ground_Zone3` |
| F5, `player_x = 3000` | — | `calculate_progress() ≈ 0.55` | `1.0` saturado: `map_length_px = 2700` contra nivel de 5446 px |
| F6/F5, `player_pos = (4550, 700)` | A y B | muerte + respawn | falla por las dos causas a la vez |
| F5, `player_pos = (2170, 710)` | ninguna (`¬C`) | muerte + respawn | **ya funciona** — debe seguir igual tras el fix |

## Expected Behavior

### Preservation Requirements

**Comportamientos que no deben cambiar:**

- Jugador apoyado en suelo/plataforma, o saltando y aterrizando sin bajar de `y = 641`: sigue donde está, sin muerte ni reposicionamiento (3.1).
- Muertes que ya funcionaban en los pits cubiertos x ∈ [2099, 2246] y x ∈ [4146, 4326]: misma posición de respawn que antes del fix (3.2, 3.3).
- `CheckpointMarker`: se activa una sola vez (color + animación) y fija el respawn vía `CheckpointSystem.set_reached_checkpoint()` (3.4).
- Flujo F5: `start_game() → load_floor() → _on_scene_loaded() → PLAYING_MAIN_LEVEL` con la misma inicialización de checkpoints; el bootstrap standalone **no** se ejecuta cuando el `LevelManager` sí cargó la escena (3.5).
- Muerte por contacto con enemigo: mismo pipeline `handle_player_death()`, `velocity = Vector2.ZERO`, input rehabilitado, estado final `PLAYING_MAIN_LEVEL` (3.6).
- `KillZone` sin autoload `LevelManager` en el árbol: `push_error` y ningún crash (3.7).
- Cuerpo que no está en el grupo `player` dentro de una `KillZone`: ignorado (3.8).
- `load_floor()` con `floor_id` sin config: fallback a piso 1 y reescritura del save (3.9, decisión vigente 7 del steering).

**Alcance:**

Toda entrada que no cumpla `inReachableVoid(X)` queda completamente inalterada por este fix. Eso incluye:

- Movimiento, salto, coyote time, input buffer y stomp del jugador (no se toca `movement_controller.gd`).
- Transiciones de piso, `entre_nivel`, `SceneLoader`, `TransitionAnimator` y el guardado en `FloorProgressData`.
- Los pisos `floor_2` y `floor_5`: solo se edita el `LevelConfigData` de floor 1 y la escena `floor_1.tscn`.
- Los sublevels (hoy deshabilitados con stubs) y `CheckpointSystem.update_checkpoints()` (código muerto, spec aparte).

El único cambio de comportamiento colateral y aceptado es el umbral vertical de muerte en los dos pits ya cubiertos: la banda de muerte pasa de `y ≈ 681..729` a `y ≈ 668..732`, así que la muerte se dispara unos pocos frames antes. La posición de respawn resultante es idéntica, y es esa la que las propiedades de preservación fijan.

## Hypothesized Root Cause

Las dos causas están confirmadas por lectura de código y de la escena (no son conjeturas):

1. **`player_ref` solo se puebla en la ruta de carga del manager** (confirmado). `_setup_player_and_camera()` únicamente se llama desde `_on_scene_loaded()`. Con boot F6 el autoload arranca, `current_state` queda en `LOADING` y `player_ref` en `null`; `handle_player_death()` hace `if not player_ref: return`. La ausencia de `push_error` en ese `return` es lo que hace el bug invisible en consola.

2. **`CheckpointSystem` nunca se inicializa con boot F6** (confirmado). `initialize_for_level()` también se llama solo desde `_on_scene_loaded()`, así que `level_start_position` y `active_checkpoint_position` quedan en `Vector2.ZERO` y `get_respawn_position()` devolvería el origen del mundo.

3. **Shape anidado bajo otro shape** (confirmado en el `.tscn`): `KillZone/CollisionShape2D/CollisionShape2D`. Godot solo agrega al `CollisionObject2D` los `CollisionShape2D` que son hijos directos; el anidado no aporta área de detección.

4. **`KillZone` colocadas por debajo de suelo sólido** (confirmado): `KillZone_Bridge1` (x ≈ 3354..3676) y `KillZone_Bridge2` (x ≈ 3683..4005) viven a y ≈ 874..908, bajo `Ground_Zone3` (top 593). Son inalcanzables: nodos muertos.

5. **Cobertura por parches en vez de suelo del mundo** (confirmado): las `KillZone` se agregaron pit por pit, así que los huecos creados después (`Pillar1`→`Pillar2` en x ∈ [4466, 4626] y `Pillar2`→`Pillar3` en x ∈ [4766, 4926]) quedaron sin cubrir. Cualquier hueco futuro repetiría el bug; un único suelo del mundo lo hace estructuralmente imposible.

6. **`map_length_px` desactualizado** (confirmado): vale 2700 en `level_registry.tres` mientras `Ground_Meta` termina en x = 5446, así que `calculate_progress()` clampea a 1.0 desde x = 2700.

## Correctness Properties

Property 1: Bug Condition — Morir en el vacío devuelve al respawn correcto

_For any_ entrada donde la condición de bug se cumple (`isBugCondition(X) == true`), tras simular la caída al vacío el sistema SHALL tener `player_ref` no nulo, dejar al jugador exactamente en `CheckpointSystem.get_respawn_position()` con `velocity == Vector2.ZERO`, terminar en estado `PLAYING_MAIN_LEVEL` y con `player.global_position.y <= 641`.

**Validates: Requirements 2.1, 2.3, 2.4**

Property 2: Preservation — Entradas fuera de la condición de bug

_For any_ entrada donde la condición de bug NO se cumple (`isBugCondition(X) == false`), el código con el fix SHALL producir el mismo resultado que el código sin el fix: si el jugador no está en vacío alcanzable, su posición no cambia (ni muerte ni reposicionamiento); si está en vacío y la muerte ya funcionaba, la posición de respawn resultante es idéntica a la de antes del fix.

**Validates: Requirements 3.1, 3.2, 3.3, 3.5, 3.6**

Property 3: Bug Condition — Cobertura total del vacío en `floor_1`

_For any_ `x` en `[0, 5446]`, la escena `floor_1.tscn` SHALL tener alguna `KillZone` con un `CollisionShape2D` **hijo directo** cuyo rect global cubra ese `x` y cuyo borde superior esté por debajo de `y = 641`; y ningún `CollisionShape2D` de una `KillZone` SHALL tener como padre otro `CollisionShape2D`.

**Validates: Requirements 2.5, 2.6**

Property 4: Bug Condition — Nunca se respawnea en el origen del mundo

_For any_ entrada donde la condición de bug se cumple y el jugador no tocó ningún checkpoint (`reached_cp == NONE`), tras la muerte el sistema SHALL dejarlo en el spawn del jugador de la escena (≈ `(100, 570)`) y nunca en `Vector2.ZERO`.

**Validates: Requirements 2.2**

Property 5: Bug Condition — El progreso del nivel no satura antes de la meta

_For any_ `x` en `[0, 5446]`, `CheckpointSystem.calculate_progress(x)` con la config de floor 1 SHALL devolver `x / 5450.0` (monótono y estrictamente menor que 1.0), consistente con la extensión real del nivel.

**Validates: Requirements 2.7**

## Fix Implementation

### Cambio 1 — Bootstrap standalone del `LevelManager`

**Archivo**: `scripts/level_system/level_manager.gd`

El bootstrap se ejecuta **al arrancar**, no de forma perezosa dentro de `handle_player_death()`: `initialize_for_level()` tiene que capturar la posición inicial del jugador, y si se inicializara en el momento de la muerte guardaría la posición de caída como "inicio del nivel" (rompería 2.2).

1. **Disparo one-shot en `_ready()`**: al final de `_ready()`, `_bootstrap_standalone_scene.call_deferred()` — el diferido corre cuando la escena principal ya está en el árbol.

2. **Nuevo método privado `_bootstrap_standalone_scene()`**:
   - Corta si `_current_scene_root != null` (el manager ya cargó la escena → ruta F5 intacta, 3.5).
   - Busca un `CharacterBody2D` en el grupo `player`; si no hay ninguno, retorna sin ruido (caso normal de `main.tscn`, que no lleva jugador).
   - Si lo hay: `_current_scene_root = get_tree().current_scene`, `_setup_player_and_camera()`, `checkpoint_system.initialize_for_level(player_ref.global_position, 0.0, config.map_length_px)`, cablear nodos del nivel y `current_state = GameFlowState.PLAYING_MAIN_LEVEL`.

3. **Extraer `_wire_level_nodes(root: Node)`** con el bloque que hoy vive inline en `_on_scene_loaded()`: conexión de `TransitionTrigger` con `target_type == 2` y registro/conexión de los `CheckpointMarker` (`marker_activated` → `_on_checkpoint_marker_reached`). Pasa a llamarse desde `_on_scene_loaded()` y desde `_bootstrap_standalone_scene()`. Se extrae porque ya hay dos llamadores reales, no "por si acaso".

4. **`handle_player_death()` deja de fallar en silencio**: `if not player_ref: push_error("LevelManager: handle_player_death sin player_ref; la muerte se ignoró."); return`. Sin nuevos flags ni estados.

Boceto:

```gdscript
## Con boot F6 la escena del piso ya está en el árbol pero el manager nunca la
## cargó: sin esto player_ref queda null y toda muerte se pierde en silencio.
func _bootstrap_standalone_scene() -> void:
	if _current_scene_root != null:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	_current_scene_root = get_tree().current_scene
	_setup_player_and_camera()
	var config = get_current_floor_config()
	checkpoint_system.initialize_for_level(
		player_ref.global_position, 0.0, config.map_length_px
	)
	_wire_level_nodes(_current_scene_root)
	current_state = GameFlowState.PLAYING_MAIN_LEVEL
	floor_started.emit(current_floor_id)
```

### Cambio 2 — Una sola `KillZone` "suelo del mundo" en `floor_1`

**Archivo**: `scenes/levels/floor_1.tscn`

1. **Borrar** `KillZone` (con su shape hijo y el shape anidado `KillZone/CollisionShape2D/CollisionShape2D`), `KillZone_Bridge1`, `KillZone_Bridge2` y `KillZone_Bridge3` (con su shape `morir`). También queda sin uso el `SubResource` `kill_zone_shape` y `pit_bridge_shape`.
2. **Agregar** un único `Area2D` `KillZone_WorldFloor` con `script = kill_zone.gd`, `position = Vector2(2750, 700)`, y un `CollisionShape2D` **hijo directo** (sin offset) con un `RectangleShape2D` de `size = Vector2(5700, 64)`.
   - Rect global resultante: x ∈ [-100, 5600], y ∈ [668, 732].
   - `top = 668 > LOWEST_WALKABLE_Y = 641`: no puede dispararse desde ninguna superficie transitable.
   - Cubre `[0, 5446]` completo con 100 px de margen a cada lado, así que los dos huecos entre pilares y cualquier hueco futuro quedan cubiertos.
   - 64 px de alto contra ~15 px/frame de velocidad terminal (900 px/s a 60 fps): sin riesgo de tunneling.

No se toca `scripts/kill_zone.gd`: su lógica (grupo `player`, `push_error` sin autoload, delegación a `handle_player_death()`) ya es correcta y está cubierta por 3.6–3.8.

### Cambio 3 — `map_length_px` de floor 1

**Archivo**: `resources/level_registry.tres`

En el `SubResource("LevelConfig_1")`, `map_length_px = 2700.0` → `5450.0`. Los configs de floor 2 y floor 5 no se tocan.

## Testing Strategy

Tests con GdUnit4 en `test/level_system/`, tabs, type hints, y fuzzers con ≥100 iteraciones para las propiedades puras. Nombres de archivo propuestos: `test_floor_1_kill_zone_coverage.gd` (geometría, pura), `test_level_manager_death_pipeline.gd` (pipeline con escena en el árbol) y `test_checkpoint_progress.gd` (progreso).

### Validation Approach

Primero se escriben los tests que **fallan sobre el código sin fix** para confirmar las dos causas; luego se verifica que el fix cumple las propiedades y que lo que ya funcionaba sigue igual.

### Exploratory Bug Condition Checking

**Objetivo**: obtener contraejemplos concretos antes de tocar nada, y confirmar o refutar las causas A y B. Si se refutan, hay que re-hipotetizar antes de implementar.

**Plan**: instanciar `floor_1.tscn` a mano en el árbol de test (equivalente a boot F6), invocar `LevelManager.handle_player_death()` y observar; y por separado recorrer el árbol de la escena calculando los rects globales de los shapes hijos directos de cada `KillZone`.

**Casos**:
1. **Pipeline desarmado (F6)**: con la escena instanciada a mano y sin pasar por `SceneLoader`, `handle_player_death()` no mueve al jugador (falla sobre el código sin fix).
2. **Respawn en el origen (F6)**: `checkpoint_system.get_respawn_position() == Vector2.ZERO` en vez de ≈ `(100, 570)` (falla sobre el código sin fix).
3. **Hueco `Pillar1`→`Pillar2`**: ningún rect global de shape hijo directo cubre x = 4550 por debajo de y = 641 (falla sobre el código sin fix).
4. **Hueco `Pillar2`→`Pillar3`**: ídem para x = 4850 (falla sobre el código sin fix).
5. **Shape anidado**: existe un `CollisionShape2D` cuyo padre es otro `CollisionShape2D` bajo una `KillZone` (falla sobre el código sin fix).
6. **`KillZone` inalcanzables**: `KillZone_Bridge1` y `KillZone_Bridge2` tienen su rect por debajo del rect sólido de `Ground_Zone3` (falla sobre el código sin fix).
7. **Progreso saturado**: `calculate_progress(3000)` con `map_length_px = 2700` devuelve 1.0 (falla sobre el código sin fix).

**Contraejemplos esperados**: `player_ref == null` con boot F6; ausencia de cobertura en x ∈ [4466, 4626] y x ∈ [4766, 4926]; shape anidado sin efecto. Causas probables: `player_ref`/`initialize_for_level()` atados a `_on_scene_loaded()`, shapes que no son hijos directos del `Area2D`, cobertura parcheada pit por pit.

### Fix Checking

**Objetivo**: para toda entrada que cumple la condición de bug, el código con el fix produce el comportamiento esperado.

**Pseudocódigo:**
```
FOR ALL X WHERE isBugCondition(X) DO
  simulateEnterVoid(X)
  ASSERT LevelManager.player_ref != null
  ASSERT player.global_position = CheckpointSystem.get_respawn_position()
  ASSERT player.velocity = Vector2.ZERO
  ASSERT LevelManager.current_state = PLAYING_MAIN_LEVEL
  ASSERT player.global_position.y <= LOWEST_WALKABLE_Y
END FOR
```

```
FOR ALL x IN [LEVEL_MIN_X, LEVEL_MAX_X] DO
  ASSERT EXISTS kz IN killZones(floor_1) SUCH THAT
           EXISTS s IN directChildShapes(kz) SUCH THAT
             globalRect(s).covers_x(x) AND globalRect(s).top > LOWEST_WALKABLE_Y
END FOR
```

```
FOR ALL X WHERE isBugCondition(X) AND X.reached_cp = NONE DO
  simulateEnterVoid(X)
  ASSERT player.global_position = scenePlayerSpawn(floor_1)
  ASSERT player.global_position != Vector2.ZERO
END FOR
```

### Preservation Checking

**Objetivo**: para toda entrada que NO cumple la condición de bug, el código con el fix produce el mismo resultado que el código sin el fix.

**Pseudocódigo:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)
END FOR

// 1. El jugador no está en vacío: nada se mueve
FOR ALL X WHERE NOT inReachableVoid(X) DO
  before ← player.global_position
  step()
  ASSERT player.global_position = before
END FOR

// 2. Muertes que ya funcionaban: mismo respawn que antes del fix
FOR ALL X WHERE inReachableVoid(X)
              AND coveredByLiveKillZone_before_fix(X)
              AND deathPipelineArmed(X) DO
  ASSERT respawnPosition_after_fix(X) = respawnPosition_before_fix(X)
END FOR
```

**Enfoque**: property-based testing para la preservación, porque genera muchas entradas sobre el dominio (posiciones del jugador dentro de la envolvente del nivel), atrapa bordes que un test manual olvida — en particular la franja `y ∈ (641, 668]`, donde el nuevo suelo del mundo aún no dispara — y da garantía fuerte de que nada cambió para `¬C(X)`.

**Plan**: registrar el comportamiento sobre el código **sin fix** para los casos que ya funcionan (pits cubiertos con boot F5, muerte por enemigo, activación de checkpoints), y escribir los tests que fijan ese comportamiento antes de implementar.

**Casos**:
1. **Pit x ∈ [2099, 2246] con boot F5**: observar la posición de respawn sin fix y verificar que es la misma con fix.
2. **Pit x ∈ [4146, 4326] con boot F5**: ídem.
3. **Jugador sobre suelo/plataforma**: observar que no hay muerte ni reposicionamiento sin fix, y que sigue igual con fix (incluye posiciones con `y <= 641`).
4. **Muerte por contacto con enemigo**: observar respawn, `velocity == Vector2.ZERO` y estado final `PLAYING_MAIN_LEVEL` sin fix, y verificar que no cambian.
5. **`CheckpointMarker`**: se activa una sola vez y fija el respawn, igual que antes.
6. **Boot F5 no dispara el bootstrap**: `_current_scene_root` proviene de `SceneLoader` y `initialize_for_level()` se llamó exactamente una vez.

### Unit Tests

- `handle_player_death()` sin `player_ref`: emite `push_error` y no crashea (3.7 análogo en el manager).
- `KillZone`: ignora cuerpos fuera del grupo `player`; con el autoload ausente hace `push_error` sin crashear.
- Estructura de `floor_1.tscn`: exactamente una `KillZone`, con su `CollisionShape2D` como hijo directo, y sin ningún shape anidado bajo otro shape (2.5, 2.6).
- `map_length_px` de floor 1 en el registry es 5450 (2.7).
- Smoke test: `floor_1.tscn` instancia sin errores tras el refactor.

### Property-Based Tests

- **Cobertura del vacío** (Property 3): fuzzer sobre `x ∈ [0, 5446]`, ≥100 iteraciones; para cada `x` existe un shape hijo directo de `KillZone` que lo cubre con `top > 641`. Pura: se resuelve cargando la escena y recorriendo el árbol, sin correr el juego.
- **Progreso del nivel** (Property 5): fuzzer sobre `x ∈ [0, 5446]`, ≥100 iteraciones; `calculate_progress(x) == x / 5450.0` y `< 1.0`. Aritmética pura.
- **Preservación de "no hay muerte fuera del vacío"** (Property 2, caso 1): fuzzer sobre posiciones con `y <= 641` dentro de la envolvente del nivel, ≥100 iteraciones; ninguna cae dentro del rect del suelo del mundo.

### Integration Tests

- Flujo F6 completo: instanciar `floor_1.tscn`, caer en cada uno de los cuatro huecos (2099..2246, 4146..4326, 4466..4626, 4766..4926) y verificar respawn en la posición esperada.
- Flujo F5 completo: `start_game()` → `floor_1` cargado por `SceneLoader` → caer en un hueco → respawn; el bootstrap standalone no interviene.
- Checkpoint + muerte: tocar `Checkpoint2`, caer en el hueco entre pilares y verificar que el respawn es el checkpoint tocado y no el spawn inicial.
