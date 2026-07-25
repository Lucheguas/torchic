# Bugfix Requirements Document

## Introduction

En `floor_1` el jugador puede caer al vacío sin morir y sin volver al checkpoint. El síntoma tiene dos causas independientes que se suman:

- **Causa A (dominante al probar con F6):** `LevelManager.handle_player_death()` aborta en silencio cuando `player_ref` es nulo. `player_ref` solo se asigna cuando el propio `LevelManager` cargó el piso vía `SceneLoader`. Al ejecutar `scenes/levels/floor_1.tscn` directo (F6) el autoload existe pero nunca carga el piso, así que **ninguna** muerte surte efecto: ni las `KillZone` ni el contacto con enemigo. Tampoco se llama `CheckpointSystem.initialize_for_level()`, por lo que `level_start_position` queda en `Vector2.ZERO`.
- **Causa B (falla también con F5):** hay huecos de vacío alcanzables en `floor_1` que ninguna `KillZone` cubre, más dos `KillZone` inalcanzables y un `CollisionShape2D` anidado dentro de otro `CollisionShape2D` que Godot ignora por completo.

Cobertura verificada leyendo `scenes/levels/floor_1.tscn` (posición del nodo + offset del shape + tamaño del shape):

| Elemento | Rango X | Y | Estado |
|---|---|---|---|
| `Ground_Main` | 2 .. 2099 | top 592 | suelo |
| `Ground_AfterPit` | 2246 .. 2646 | top 593 | suelo |
| `Ground_Zone3` | 2646 .. 4146 | top 593 | suelo |
| `Pillar1` / `Pillar2` / `Pillar3` | 4326..4466 / 4626..4766 / 4926..5066 | 593 .. 641 | suelo |
| `Ground_Meta` | 5046 .. 5446 | top 593 | suelo |
| `KillZone` (shape hijo directo) | 2058 .. 2296 | 697 .. 729 | cubre el hueco 2099→2246 ✅ |
| `KillZone/CollisionShape2D/CollisionShape2D` | ≈4536 .. 4774 | ≈722 .. 754 | **ignorado por Godot** ❌ |
| `KillZone_Bridge1` | ≈3354 .. 3676 | 874 .. 906 | debajo de suelo sólido, inalcanzable ❌ |
| `KillZone_Bridge2` | ≈3683 .. 4005 | 876 .. 908 | debajo de suelo sólido, inalcanzable ❌ |
| `KillZone_Bridge3` | ≈4007 .. 4330 | 874 .. 906 | cubre el hueco 4146→4326 ✅ |
| Hueco Pillar1→Pillar2 | **4466 .. 4626** | — | **sin cobertura** ❌ |
| Hueco Pillar2→Pillar3 | **4766 .. 4926** | — | **sin cobertura** ❌ |

La cota más baja transitable del nivel es `y = 641` (base de los pilares).

### Alcance acordado

Entra en este fix:

1. La muerte funciona tanto con F5 (`main.tscn`) como con F6 (`floor_1.tscn` directo).
2. Una única `KillZone` "suelo del mundo" que cubre todo el ancho del nivel por debajo de `y = 641`, más la limpieza de los nodos rotos/inalcanzables y del shape anidado.
3. Corregir `map_length_px` de floor 1 en `resources/level_registry.tres` (2700 → 5450).

Queda fuera (bugs distintos, spec propio):

- Cablear `CheckpointSystem.update_checkpoints()` (checkpoints por progreso 33%/66%, hoy código muerto).
- Aplicar el mismo patrón a `floor_2` (franja descubierta de ~15 px entre `KillZone_1` y `G2_Mid`).
- Resetear el estado del nivel al respawnear (enemigos muertos, triggers one-shot).

## Bug Analysis

### Current Behavior (Defect)

Lo que ocurre hoy:

1.1 WHEN se ejecuta `floor_1.tscn` con F6 (el `LevelManager` autoload existe pero no cargó el piso) THEN the system deja `player_ref` en `null` y `handle_player_death()` retorna sin efecto y sin ningún mensaje en consola, así que ninguna muerte (KillZone ni contacto con enemigo) reposiciona al jugador

1.2 WHEN se ejecuta `floor_1.tscn` con F6 THEN the system nunca llama `CheckpointSystem.initialize_for_level()`, dejando `level_start_position` en `Vector2.ZERO`, de modo que el respawn apuntaría al origen del mundo en vez de al spawn del nivel

1.3 WHEN el jugador cae en el hueco entre `Pillar1` y `Pillar2` (x ∈ [4466, 4626]) THEN the system lo deja caer indefinidamente sin muerte ni respawn, porque ninguna `KillZone` cubre ese tramo

1.4 WHEN el jugador cae en el hueco entre `Pillar2` y `Pillar3` (x ∈ [4766, 4926]) THEN the system lo deja caer indefinidamente sin muerte ni respawn

1.5 WHEN el jugador atraviesa la zona del shape `KillZone/CollisionShape2D/CollisionShape2D` (global ≈ (4655, 738), 238x32) THEN the system no detecta nada, porque Godot solo registra los `CollisionShape2D` que son hijos **directos** del `CollisionObject2D` y ese está anidado bajo otro shape

1.6 WHEN el jugador recorre la zona 3 (x ∈ [2646, 4146]) THEN the system nunca dispara `KillZone_Bridge1` ni `KillZone_Bridge2`, porque están a y ≈ 874..908, por debajo del suelo sólido `Ground_Zone3`: son nodos muertos

1.7 WHEN el jugador pasa x ≈ 2700 en floor 1 THEN the system calcula `calculate_progress()` saturado en 1.0, porque `map_length_px` vale 2700 mientras el nivel llega a x ≈ 5446

### Expected Behavior (Correct)

Lo que debe pasar en su lugar:

2.1 WHEN se ejecuta `floor_1.tscn` con F6 THEN the system SHALL resolver `player_ref` desde el grupo `player` de la escena ya presente en el árbol e inicializar el `CheckpointSystem`, de modo que toda muerte reposicione al jugador; si no encuentra jugador, SHALL reportar el problema con `push_error` en vez de retornar en silencio

2.2 WHEN se ejecuta `floor_1.tscn` con F6 y el jugador muere sin haber tocado ningún checkpoint THEN the system SHALL reposicionarlo en la posición inicial del jugador de la escena (≈ (100, 570)), nunca en `Vector2.ZERO`

2.3 WHEN el jugador cae en el hueco entre `Pillar1` y `Pillar2` (x ∈ [4466, 4626]) THEN the system SHALL matarlo y reposicionarlo en `CheckpointSystem.get_respawn_position()` con `velocity` en cero

2.4 WHEN el jugador cae en el hueco entre `Pillar2` y `Pillar3` (x ∈ [4766, 4926]) THEN the system SHALL matarlo y reposicionarlo en `CheckpointSystem.get_respawn_position()` con `velocity` en cero

2.5 WHEN se carga `floor_1.tscn` THEN the system SHALL tener todos los `CollisionShape2D` de cada `KillZone` como hijos directos del `Area2D` (sin shapes anidados dentro de otro shape)

2.6 WHEN se carga `floor_1.tscn` THEN the system SHALL no contener `KillZone` ubicadas por debajo de suelo sólido e inalcanzables; la cobertura de vacío SHALL provenir de una única `KillZone` "suelo del mundo" que abarque todo el ancho del nivel (x ≈ [-100, 5600]) por debajo de la cota transitable más baja (y = 641)

2.7 WHEN se consulta la config de floor 1 THEN the system SHALL exponer `map_length_px = 5450`, consistente con la extensión real del nivel (`Ground_Meta` termina en x = 5446)

### Unchanged Behavior (Regression Prevention)

Comportamiento existente que debe preservarse:

3.1 WHEN el jugador está apoyado en cualquier suelo o plataforma, o salta y aterriza sin bajar de y = 641 THEN the system SHALL CONTINUE TO dejarlo donde está, sin muerte ni reposicionamiento

3.2 WHEN el jugador cae en el pit ya cubierto entre `Ground_Main` y `Ground_AfterPit` (x ∈ [2099, 2246]) THEN the system SHALL CONTINUE TO matarlo y reposicionarlo en la misma posición de respawn que antes del fix

3.3 WHEN el jugador cae en el pit ya cubierto entre `Ground_Zone3` y `Pillar1` (x ∈ [4146, 4326]) THEN the system SHALL CONTINUE TO matarlo y reposicionarlo en la misma posición de respawn que antes del fix

3.4 WHEN el jugador toca un `CheckpointMarker` THEN the system SHALL CONTINUE TO activarlo una sola vez (color + animación) y fijar ese punto como respawn vía `CheckpointSystem.set_reached_checkpoint()`

3.5 WHEN el juego arranca con F5 desde `main.tscn` THEN the system SHALL CONTINUE TO seguir el flujo `start_game() → load_floor() → _on_scene_loaded() → PLAYING_MAIN_LEVEL` con la misma inicialización de checkpoints; la auto-inicialización de 2.1 SHALL no ejecutarse cuando el `LevelManager` sí cargó la escena

3.6 WHEN el jugador muere por contacto con un enemigo (`MovementController._check_enemy_contact_damage()`) THEN the system SHALL CONTINUE TO respawnearlo por el mismo pipeline `handle_player_death()`, con `velocity = Vector2.ZERO`, input rehabilitado y estado final `PLAYING_MAIN_LEVEL`

3.7 WHEN una `KillZone` detecta al jugador y el autoload `LevelManager` no existe en el árbol THEN the system SHALL CONTINUE TO reportar `push_error` y no crashear

3.8 WHEN un cuerpo que no está en el grupo `player` entra en una `KillZone` THEN the system SHALL CONTINUE TO ignorarlo

3.9 WHEN se pide un `floor_id` sin config en el registry THEN the system SHALL CONTINUE TO caer a piso 1 y reescribir el save (decisión vigente 7 del steering)

## Formalización de la condición de bug

### Espacio de entrada

```pascal
TYPE DeathInput
  boot_mode      : {F5_MAIN, F6_SCENE}   // F5 = main.tscn, F6 = floor_1.tscn directo
  player_pos     : Vector2               // posición global del jugador
  reached_cp     : Vector2 or NONE       // último CheckpointMarker tocado
END TYPE

CONST LOWEST_WALKABLE_Y := 641.0   // base de los pilares de floor_1
CONST LEVEL_MIN_X       := 0.0
CONST LEVEL_MAX_X       := 5446.0
```

### Predicados auxiliares

```pascal
// El jugador está en vacío alcanzable: por debajo de toda superficie
// transitable y dentro de la extensión horizontal del nivel.
FUNCTION inReachableVoid(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  RETURN X.player_pos.y > LOWEST_WALKABLE_Y
     AND X.player_pos.x >= LEVEL_MIN_X
     AND X.player_pos.x <= LEVEL_MAX_X
END FUNCTION

// Área de muerte efectiva en la escena original: solo cuentan los
// CollisionShape2D que son hijos DIRECTOS de un Area2D con script KillZone.
FUNCTION coveredByLiveKillZone(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  RETURN EXISTS kz IN killZones(floor_1) SUCH THAT
           EXISTS s IN directChildShapes(kz) SUCH THAT
             contains(globalRect(s), X.player_pos)
END FUNCTION

// El pipeline de muerte del LevelManager está operativo.
FUNCTION deathPipelineArmed(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  RETURN LevelManager.player_ref != null
END FUNCTION
```

### Condición de bug C(X)

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type DeathInput
  OUTPUT: boolean

  // A: el jugador entra en vacío pero el pipeline se traga la muerte (F6)
  // B: el jugador entra en vacío que ninguna KillZone viva cubre
  RETURN inReachableVoid(X)
     AND (NOT deathPipelineArmed(X) OR NOT coveredByLiveKillZone(X))
END FUNCTION
```

Instancias concretas de `C(X)`:

| Contraejemplo | Rama |
|---|---|
| `boot_mode = F6_SCENE`, `player_pos = (2170, 710)` (pit ya cubierto) | A — `player_ref` nulo |
| `boot_mode = F5_MAIN`, `player_pos = (4550, 700)` (Pillar1→Pillar2) | B — sin cobertura |
| `boot_mode = F5_MAIN`, `player_pos = (4850, 700)` (Pillar2→Pillar3) | B — sin cobertura |
| `boot_mode = F6_SCENE`, `player_pos = (4550, 700)` | A y B |

### Propiedad de corrección (Fix Checking)

```pascal
// Property: Fix Checking — morir en el vacío devuelve al respawn correcto
FOR ALL X WHERE isBugCondition(X) DO
  simulateEnterVoid(X)
  ASSERT LevelManager.player_ref != null
  ASSERT player.global_position = CheckpointSystem.get_respawn_position()
  ASSERT player.velocity = Vector2.ZERO
  ASSERT LevelManager.current_state = PLAYING_MAIN_LEVEL
  ASSERT player.global_position.y <= LOWEST_WALKABLE_Y
END FOR
```

```pascal
// Property: Fix Checking — cobertura total del vacío en floor_1
FOR ALL x IN [LEVEL_MIN_X, LEVEL_MAX_X] DO
  ASSERT EXISTS kz IN killZones(floor_1) SUCH THAT
           EXISTS s IN directChildShapes(kz) SUCH THAT
             globalRect(s).covers_x(x) AND globalRect(s).top > LOWEST_WALKABLE_Y
END FOR
```

```pascal
// Property: Fix Checking — sin respawn en el origen del mundo
FOR ALL X WHERE isBugCondition(X) AND X.reached_cp = NONE DO
  simulateEnterVoid(X)
  ASSERT player.global_position = scenePlayerSpawn(floor_1)   // ≈ (100, 570)
  ASSERT player.global_position != Vector2.ZERO
END FOR
```

### Propiedad de preservación (Preservation Checking)

Con `F` = comportamiento antes del fix y `F'` = comportamiento después del fix:

```pascal
// Property: Preservation Checking — entradas no afectadas por el bug
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)
END FOR
```

Instanciada sobre los dos subconjuntos que importan:

```pascal
// 1. El jugador no está en vacío: nada se mueve
FOR ALL X WHERE NOT inReachableVoid(X) DO
  before ← player.global_position
  step()
  ASSERT player.global_position = before   // sin muerte ni reposicionamiento
END FOR

// 2. Muertes que YA funcionaban: mismo resultado que antes del fix
FOR ALL X WHERE inReachableVoid(X)
              AND coveredByLiveKillZone_before_fix(X)
              AND deathPipelineArmed(X) DO
  ASSERT respawnPosition_after_fix(X) = respawnPosition_before_fix(X)
END FOR
```

**Definiciones:**

- **F**: el comportamiento del código antes del fix (`floor_1.tscn` y `level_manager.gd` actuales).
- **F'**: el comportamiento después del fix.
- **C(X)**: `isBugCondition(X)` — el jugador entra en vacío alcanzable y no muere ni respawnea.
- **P(result)**: el jugador queda en `get_respawn_position()`, con velocidad cero, en estado `PLAYING_MAIN_LEVEL`, por encima de la cota transitable más baja.
- **¬C(X)**: el jugador no está en vacío, o está en vacío y el pipeline ya funcionaba correctamente.

### Notas para los tests (GdUnit4)

- Las propiedades sobre geometría (cobertura de `x` en `[0, 5446]`, shapes hijos directos, `top > 641`) son puras: se validan cargando `floor_1.tscn` y recorriendo el árbol, sin ejecutar el juego. Son el mejor candidato a property-based test con fuzzer de ≥100 iteraciones sobre `x`.
- Las propiedades sobre el pipeline de muerte requieren escena en el árbol: se validan invocando `handle_player_death()` con el piso instanciado a mano (simulando F6) y con el piso cargado por `LevelManager` (simulando F5).
- No hay riesgo de tunneling: la velocidad terminal del jugador es 900 px/s (~15 px/frame a 60 fps) y la banda de muerte propuesta tiene 64 px de alto.
