# Torchic — Arquitectura y Convenciones

Este archivo describe la estructura, lenguaje, uso de POO y filosofía de código del proyecto **Torchic**, un platformer 2D pixel art en Godot 4.7. Toda contribución (spec, refactor o feature nueva) debe respetar estas reglas.

## Stack

- **Motor**: Godot Engine 4.7 (GL Compatibility renderer)
- **Lenguaje**: GDScript exclusivamente (no C#, no .NET)
- **Testing**: GdUnit4 (config en `.gdunit4.cfg`, tests en `test/`)
- **Assets**: Pixel art, backgrounds en `assets/backgrounds/`, sprites en la raíz

## Filosofía de código (regla dura)

**Simplicidad sobre generalidad.** Cada línea agregada tiene que resolver un problema real en el momento. Reglas concretas:

1. **No agregues abstracciones "por si acaso".** Si no existe un segundo usuario del código, no crees interfaces, base classes o resources para "el futuro". Refactorizar cuando aparezca el segundo usuario es más barato que mantener abstracción inútil.
2. **No agregues parámetros o flags que no se usen hoy.** Si un método solo se llama con `amount = 1`, no aceptes `amount` con default hasta que aparezca el caso `amount = 2`.
3. **Prefiere composición sobre herencia** salvo cuando ya haya 2+ subclases con lógica compartida real.
4. **No agregues validación defensiva innecesaria.** Clamping de rangos numéricos sí (evita bugs físicos). Try/catch en operaciones que no fallan, no. `null`-checks solo donde `null` es realmente un valor posible del dominio.
5. **No agregues logging, telemetría, o hooks de extensión** sin necesidad concreta. `push_error`/`push_warning` sí donde ayudan a diagnosticar rápido; `print` de debug, no.
6. **Comentarios explican *por qué*, no *qué*.** El código debe expresar el "qué" por sí solo.
7. **Los tests cubren propiedades y casos edge reales,** no cobertura por cobertura. Un test que reafirma el compilador (por ejemplo, verificar que un `class_name` está declarado) sobra.

Si un spec pide algo que huele a sobreingeniería, cuestiónalo antes de implementarlo.

## Uso de POO

El proyecto sí usa POO, con estas convenciones:

### Herencia

- Todas las clases GDScript relevantes declaran `class_name` para exponerse como tipo de primera clase.
- Herencia solo cuando hay 2+ subclases que comparten lógica no trivial. Ejemplos válidos:
  - `PlayerTrigger` (Area2D) → `TransitionTrigger`, `SublevelExitTrigger`, `CheckpointMarker`
  - `BaseEnemy` (CharacterBody2D) → `EnemyBasic` (y futuros enemigos)
- La clase base implementa el patrón compartido; las subclases sobreescriben métodos virtuales (`_on_player_entered`, `_update_behavior`).
- Nombres de métodos virtuales usan prefijo `_` para indicar "override point".

### Composición

- Preferida cuando la relación es "tiene un" y no "es un".
- Ejemplo: `MovementController` **tiene un** `ModifierStack` (no hereda de él). Los modifiers se guardan en un `RefCounted` interno, no en fields sueltos.
- Composición se hace por field, no por node hijo, salvo que el objeto necesite estar en el árbol de escena (por ejemplo, un subsistema como `CheckpointSystem` bajo `LevelManager`).

### Encapsulación

- Miembros privados con prefijo `_` (convención GDScript, no hay `private` real).
- API pública son los métodos sin prefijo. Los setters exponen puntos de mutación controlados (con clamping cuando el rango importa).
- Los signals son el mecanismo público de observación (no eventos globales ad-hoc).

### Resources

- `Resource` (y subclases como `RefCounted`) para datos serializables o estado sin nodo:
  - `SubLevelConfig`, `LevelConfigData`, `FloorProgressData`, `LevelRegistry` → datos del sistema de niveles
  - `ModifierStack` → estado de modifiers del jugador
- No usar `Resource` para lógica activa; solo datos + operaciones puras sobre esos datos.

### Autoloads

- Uso limitado a servicios genuinamente globales. Actualmente solo `LevelManager`.
- No abusar de autoloads como sustituto de referencias directas.

## Mapa de clases

### Player / movimiento

| Clase | Archivo | Base | Rol |
|---|---|---|---|
| `MovementController` | `scripts/movement_controller.gd` | `CharacterBody2D` | Controla el movimiento del jugador: horizontal instantáneo, salto variable, gravedad asimétrica, coyote time, input buffer, stomp bounce, evento de aterrizaje. Compone un `ModifierStack`. |
| `ModifierStack` | `scripts/modifier_stack.gd` | `RefCounted` | Almacena los modificadores del jugador (`base_speed`, `speed_modifier`, `jump_height_bonus`, `double_jump_enabled`, `stomp_bounce_multiplier`) con setters que clampean rangos. Composición dentro de `MovementController`. |

### Enemigos

| Clase | Archivo | Base | Rol |
|---|---|---|---|
| `BaseEnemy` | `scripts/enemies/base_enemy.gd` | `CharacterBody2D` | Clase base con `hp: int` y `take_stomp_damage(amount)`. `queue_free()` cuando `hp <= 0`. |
| `EnemyBasic` | `scripts/enemy_basic.gd` | `BaseEnemy` | Enemigo Tier 0.5 del tutorial. Patrulla horizontal entre dos límites. Detección de stomp desde arriba vía `StompArea` (Area2D). |

### Triggers y zonas

| Clase | Archivo | Base | Rol |
|---|---|---|---|
| `PlayerTrigger` | `scripts/triggers/player_trigger.gd` | `Area2D` | Base one-shot que detecta al jugador en el grupo `player`, llama al virtual `_on_player_entered(body)` una sola vez y se desconecta. |
| `TransitionTrigger` | `scripts/level_system/transition_trigger.gd` | `PlayerTrigger` | Emite `triggered(self)` para que `LevelManager` decida qué cargar (sublevel, entre_nivel, siguiente piso). |
| `SublevelExitTrigger` | `scripts/level_system/sublevel_exit_trigger.gd` | `PlayerTrigger` | Llama a `LevelManager.complete_sublevel()`. Se pone al final de cada sublevel. |
| `CheckpointMarker` | `scripts/level_system/checkpoint_marker.gd` | `PlayerTrigger` | Marca visual de checkpoint. Al primer contacto se activa (color + animación) y emite `marker_activated`. |
| `KillZone` | `scripts/kill_zone.gd` | `Area2D` | Zona de muerte (pits/abismos). Delega a `LevelManager.handle_player_death()`; no muta al jugador directamente. |

### Sistema de niveles

| Clase | Archivo | Base | Rol |
|---|---|---|---|
| `LevelManager` | `scripts/level_system/level_manager.gd` | `Node` (autoload) | Orquestador global. Estados: `LOADING`, `PLAYING_MAIN_LEVEL`, `TRANSITION_TO_SUBLEVEL`, `PLAYING_SUBLEVEL`, `TRANSITION_TO_MAIN`, `TRANSITION_TO_ENTRE_NIVEL`, `ENTRE_NIVEL`, `RESPAWNING`. Compone `CheckpointSystem`, `CameraController`, `TransitionAnimator`, `SceneLoader`. Fallback a piso 1 si el config del piso pedido no existe. |
| `CheckpointSystem` | `scripts/level_system/checkpoint_system.gd` | `Node` | Gestiona checkpoints del piso principal y de sublevels. Activa checkpoints por progreso horizontal (33% y 66%). |
| `CameraController` | `scripts/level_system/camera_controller.gd` | `Node` | Aplica zoom/offset/rotation por tipo de sublevel (CHASE, INFILTRATION, PRECISION_AIMING, ENVIRONMENTAL_PUZZLE). Reset al piso principal restaura zoom `(1, 1)`. |
| `TransitionAnimator` | `scripts/level_system/transition_animator.gd` | `Node` | Reproduce transiciones visuales (DOOR, etc.) entre escenas. Emite `transition_finished`. |
| `SceneLoader` | `scripts/level_system/scene_loader.gd` | `Node` | Carga/descarga escenas asíncronamente con `ResourceLoader`. Emite `scene_loaded`, `load_failed`. |

### Data resources

| Clase | Archivo | Base | Rol |
|---|---|---|---|
| `SubLevelConfig` | `scripts/level_system/data/sublevel_config.gd` | `Resource` | Config de un sublevel: id, tipo, path de escena, tipo de transición, time limit opcional. |
| `LevelConfigData` | `scripts/level_system/data/level_config_data.gd` | `Resource` | Config de un piso: path de escena, longitud, config de entre_nivel, tipo de boss. |
| `LevelRegistry` | `scripts/level_system/data/level_registry.gd` | `Resource` | Array de `LevelConfigData`. Recurso guardado en `resources/level_registry.tres`. |
| `FloorProgressData` | `scripts/level_system/data/floor_progress_data.gd` | `Resource` | Progreso persistido en `user://floor_progress.tres`: piso actual, sublevels completados, checkpoints activos, estado del jugador. |

### Otros

| Archivo | Rol |
|---|---|
| `scripts/game_startup.gd` | Script del root de `main.tscn`. Espera un frame y llama `LevelManager.start_game(false)`. |

## Escenas relevantes

- `scenes/main.tscn` — punto de entrada del proyecto
- `scenes/player.tscn` — instancia del jugador con `MovementController` y sprite escalado
- `scenes/enemy_basic.tscn` — instancia de `EnemyBasic` (cuerpo + StompArea)
- `scenes/kill_zone.tscn` — instancia de `KillZone` con área rectangular
- `scenes/levels/floor_1.tscn` — tutorial completo con Bliss como fondo, 6 zonas, 2 enemigos, checkpoint, sublevel entry, kill zone, level end
- `scenes/level_system/*` — instancias de checkpoint marker, transition trigger, etc.

## Convenciones de estilo GDScript

- **Indentación**: tabs (no spaces) — consistente con el resto del proyecto.
- **Type hints**: siempre en firmas de métodos y variables cuando el tipo no sea obvio de la asignación.
- **Docstrings**: usar `##` para docstrings de clase, campo o método. Solo cuando aporten información no obvia.
- **Naming**: `snake_case` para variables/funciones, `PascalCase` para `class_name`, `SCREAMING_SNAKE_CASE` para constantes.
- **Signals**: nombres en pasado (`landed`, `stomp_bounced`, `checkpoint_activated`) — describen algo que ya ocurrió.
- **Grupos exportados**: `@export_group("Nombre")` para agrupar tuning parameters en el Inspector.

## Testing

- **Framework**: GdUnit4, config en `.gdunit4.cfg`.
- **Ubicación**: `test/` (o `tests/` según el spec).
- **Property-based tests**: usar los fuzzers de GdUnit4 con ≥100 iteraciones para propiedades matemáticas puras (clamping, interpolación, aritmética de damage).
- **Unit tests**: casos edge específicos, no cobertura por cobertura.
- **Smoke tests**: al menos uno que valide que `floor_1.tscn` carga sin errores tras cualquier refactor.

## Decisiones vigentes que no se deben revertir

Estas son decisiones que ya se tomaron y no se relitigan sin razón fuerte:

1. **GDScript, no C#.** Iteración rápida > rendimiento de código gestionado.
2. **Timers son floats decrementados en `_physics_process`, no `Timer` nodes.** Determinístico y sin overhead de nodos.
3. **Movimiento horizontal instantáneo (sin aceleración/desaceleración).** Es una decisión de game feel del GDD.
4. **`_previous_velocity_y` se captura antes de `move_and_slide()`** para detectar aterrizajes correctamente.
5. **Sprite del jugador tiene escala en el `.tscn` y `_animate_walk` la respeta** multiplicando en vez de resetear (bug histórico, no volver a caer).
6. **Los enemigos detectan stomp por posición del jugador** (por encima), no por `velocity.y > 0` — la velocidad puede haberse zeroed por resolución de colisión.
7. **`LevelManager.load_floor()` cae a piso 1** si el piso pedido no tiene config (evita pantalla vacía cuando el save tiene `current_floor` inexistente).
