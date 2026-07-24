# 🔥 Torchic - Documentación Completa del Proyecto

## Información General

| Campo | Valor |
|-------|-------|
| **Nombre** | Torchic |
| **Motor** | Godot 4.7 |
| **Renderer** | GL Compatibility |
| **Género** | Platformer 2D con RPG y combate |
| **Escena principal** | `res://scenes/main.tscn` |
| **Autoloads** | `LevelManager` → `res://scenes/level_system/level_manager.tscn` |
| **Testing** | GdUnit4 |

---

## Estructura de Archivos

```
torchic/
├── project.godot
├── icon.svg
├── personaje-sin-fondo.png
├── node_2d.tscn
├── Game Design Document GDD - Platformer Core System v2.md
│
├── resources/
│   └── level_registry.tres          # Registro de niveles (Resource)
│
├── scenes/
│   ├── main.tscn                    # Escena principal (entry point)
│   ├── player.tscn                  # Escena del jugador
│   ├── entre_nivel.tscn             # Zona de tienda entre pisos
│   ├── level_system/
│   │   ├── level_manager.tscn       # Autoload: orquestador de niveles
│   │   ├── checkpoint_marker.tscn   # Marcador visual de checkpoint
│   │   └── transition_trigger.tscn  # Zona trigger de transición
│   └── levels/
│       ├── floor_1.tscn             # Piso 1 (funcional)
│       ├── floor_5.tscn             # Piso 5 (placeholder)
│       ├── sublevel_chase_1.tscn    # Subnivel tipo persecución
│       └── sublevel_precision_1.tscn # Subnivel de precisión (placeholder)
│
├── scripts/
│   ├── game_startup.gd              # Inicializador del juego
│   ├── player.gd                    # Controller legacy (sin uso activo)
│   ├── movement_controller.gd       # Controller principal del jugador
│   └── level_system/
│       ├── level_manager.gd         # Autoload: máquina de estados del flujo
│       ├── scene_loader.gd          # Cargador asíncrono de escenas
│       ├── checkpoint_system.gd     # Sistema de checkpoints automáticos
│       ├── checkpoint_marker.gd     # Nodo visual de bandera checkpoint
│       ├── transition_animator.gd   # Animaciones de transición (1.5s)
│       ├── transition_trigger.gd    # Trigger Area2D para transiciones
│       ├── sublevel_exit_trigger.gd # Trigger de salida de subniveles
│       └── data/
│           ├── level_registry.gd    # Resource: catálogo de pisos
│           ├── level_config_data.gd # Resource: config de un piso
│           ├── sublevel_config.gd   # Resource: config de un subnivel
│           └── floor_progress_data.gd # Resource: progreso guardado
│
└── test/
    └── movement/
        └── .gdkeep                  # Directorio para tests de movimiento
```

---

## Controles de Input

| Acción | Teclas |
|--------|--------|
| `move_left` | A, Flecha Izquierda |
| `move_right` | D, Flecha Derecha |
| `jump` | W, Flecha Arriba, Espacio |

---

## Arquitectura del Sistema

### Flujo de Juego (Máquina de Estados)

```
LOADING → PLAYING_MAIN_LEVEL ⇄ TRANSITION_TO_SUBLEVEL → PLAYING_SUBLEVEL
    ↕                                                         ↕
RESPAWNING                                    TRANSITION_TO_MAIN
    ↕
TRANSITION_TO_ENTRE_NIVEL → ENTRE_NIVEL → (siguiente piso)
```

**Estados del `LevelManager`:**
- `LOADING` — Cargando escena de piso
- `PLAYING_MAIN_LEVEL` — Gameplay en el nivel principal
- `TRANSITION_TO_SUBLEVEL` — Animación de entrada a subnivel
- `PLAYING_SUBLEVEL` — Gameplay dentro del subnivel
- `TRANSITION_TO_MAIN` — Animación de salida del subnivel
- `TRANSITION_TO_ENTRE_NIVEL` — Transición a zona de tienda
- `ENTRE_NIVEL` — Zona de descanso/tienda entre pisos
- `RESPAWNING` — Reaparición del jugador tras muerte

### Cámara (Follow_Camera)

La cámara es un nodo `Camera2D` hijo directo del `Player` que sigue al jugador con una
perspectiva única y constante: zoom `Vector2(1, 1)`, offset `Vector2(0, 0)` y rotación `0.0`.
No hay cambios de perspectiva por tipo de subnivel; el `LevelManager` solo garantiza que la
cámara exista y quede activa (`current`) al cargar cada piso.

---

## Scripts — Descripción Detallada

### `scripts/movement_controller.gd`
**Clase:** `MovementController` (extiende `CharacterBody2D`)

Controller principal del jugador. Maneja:
- **Movimiento horizontal** instantáneo (sin aceleración)
- **Salto variable** (altura depende del tiempo de presión del botón)
- **Gravedad asimétrica** (más pesada al bajar, multiplicador 1.6x)
- **Coyote time** (100ms de gracia al caer de una plataforma)
- **Input buffer** (120ms para registrar salto antes de aterrizar)
- **Stomp bounce** (rebote al pisar enemigos, amplificado si se mantiene jump)
- **Doble salto** (activable por equipamiento)
- **Animación procedural** de caminata (bobbing, tilt, squash & stretch)

**Parámetros exportados:**
| Grupo | Parámetro | Valor Default |
|-------|-----------|---------------|
| Horizontal | `base_pixel_speed` | 300 px/s |
| Jump | `jump_velocity` | -450 |
| Jump | `jump_cut_multiplier` | 0.4 |
| Jump | `min_jump_time` | 0.08s |
| Gravity | `gravity_up_multiplier` | 1.0 |
| Gravity | `gravity_down_multiplier` | 1.6 |
| Gravity | `terminal_velocity` | 900 |
| Coyote | `coyote_time_duration` | 0.1s |
| Buffer | `input_buffer_duration` | 0.12s |
| Stomp | `stomp_bounce_velocity` | -350 |
| Stomp | `stomp_bounce_hold_velocity` | -500 |
| Landing | `landing_velocity_threshold` | 200 |

**Señales:**
- `landed(impact_velocity: float)` — al aterrizar con impacto significativo
- `stomp_bounced()` — al rebotar tras pisar un enemigo

**Métodos públicos (setters para sistemas externos):**
- `set_base_speed(value)` — velocidad por nivel (1.0–1.7)
- `set_speed_modifier(value)` — bonus de equipo (0.0–0.5)
- `set_jump_height_bonus(percent)` — bonus altura salto (0.0–1.0)
- `set_double_jump_enabled(enabled)` — activa doble salto
- `set_stomp_bounce_multiplier(mult)` — multiplicador rebote (1.0–2.0)
- `notify_stomp_hit()` — notifica colisión de pisotón

**Funciones estáticas (puras, testeables):**
- `calculate_effective_speed(base, speed, modifier) → float`
- `apply_gravity(vy, gravity, multiplier, delta, terminal) → float`
- `apply_jump_cut(vy, cut_multiplier) → float`
- `interpolate_base_speed(level) → float`

---

### `scripts/level_system/level_manager.gd`
**Autoload singleton** que orquesta todo el flujo del juego.

**Señales:**
- `floor_started(floor_id)` / `floor_completed(floor_id)`
- `sublevel_entered(config)` / `sublevel_completed(config)`
- `entre_nivel_entered()` / `entre_nivel_exited()`
- `player_respawned(position)`
- `game_state_saved()`

**Métodos públicos:**
- `start_game(from_save)` — inicia el juego (nuevo o desde guardado)
- `load_floor(floor_id)` — carga un piso
- `complete_floor()` — marca piso completado, va a entre-nivel
- `enter_sublevel(trigger)` — entra a subnivel desde trigger
- `complete_sublevel()` — completa subnivel, vuelve al nivel principal
- `exit_entre_nivel()` — sale de la tienda, carga siguiente piso
- `handle_player_death()` — respawn en checkpoint activo
- `save_progress()` — guarda progreso a disco

---

### `scripts/level_system/scene_loader.gd`
**Clase:** `SceneLoader`

Cargador asíncrono de escenas usando `ResourceLoader.load_threaded_*`.
- Retry automático (1 intento extra)
- Señal de progreso para barras de carga
- Precarga durante entre-nivel

---

### `scripts/level_system/checkpoint_system.gd`
**Clase:** `CheckpointSystem`

- Checkpoints automáticos al 33% y 66% del mapa
- Soporte para checkpoints de subnivel (respawn al inicio del subnivel)
- Prioridad de respawn: subnivel > checkpoint activo > inicio del nivel

---

### `scripts/level_system/transition_animator.gd`
**Clase:** `TransitionAnimator`

Animaciones de transición de 1.5 segundos con Tween.
Tipos: `DOOR`, `PIPE`, `DATA_PORTAL`

---

### `scripts/level_system/transition_trigger.gd`
**Clase:** `TransitionTrigger` (extiende `Area2D`)

Zona trigger que inicia transiciones al entrar el jugador.
Target types: `SUBLEVEL`, `ENTRE_NIVEL`, `NEXT_FLOOR`

---

### `scripts/level_system/sublevel_exit_trigger.gd`
**Clase:** `SublevelExitTrigger` (extiende `Area2D`)

Trigger de salida en subniveles. Llama a `LevelManager.complete_sublevel()`.

---

## Data Resources

### `LevelRegistry` (`resources/level_registry.tres`)
Catálogo central de todos los pisos. Actualmente registra:
- **Floor 1** — Fase Bosque, 5000px, boss mini, 1 subnivel chase
- **Floor 5** — Fase Bosque, 7000px, boss major, 1 subnivel precisión (60s time limit)

### `LevelConfigData`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `floor_id` | int | Identificador del piso (1-15) |
| `phase` | enum | FOREST / CAVE / LABORATORY |
| `scene_path` | String | Ruta a la escena .tscn |
| `sublevels` | Array[SubLevelConfig] | Subniveles del piso |
| `boss_type` | enum | MINI / MAJOR |
| `entre_nivel_scene_path` | String | Escena entre-nivel |
| `map_length_px` | float | Largo del mapa en píxeles |

**Fases por piso:** Pisos 1-5 → Forest, 6-10 → Cave, 11-15 → Laboratory
**Boss Major en:** Piso 5, 10, 15

### `SubLevelConfig`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `sublevel_id` | String | ID único |
| `scene_path` | String | Ruta a la escena del subnivel |
| `transition_type` | enum | DOOR / PIPE / DATA_PORTAL |
| `has_time_limit` | bool | Si tiene límite de tiempo |
| `time_limit_seconds` | float | Segundos de tiempo límite |

### `FloorProgressData` (guardado en `user://floor_progress.tres`)
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `highest_floor_reached` | int | Piso más alto alcanzado |
| `current_floor` | int | Piso actual |
| `completed_sublevels` | Dictionary | {floor_id: [sublevel_ids]} |
| `active_checkpoints` | Dictionary | {floor_id: checkpoint_index} |
| `player_hp` | int | HP actual |
| `player_tokens` | int | Tokens acumulados |
| `player_exp` | int | Experiencia total |
| `player_level` | int | Nivel del jugador |
| `player_equipment` | Array[String] | Equipo activo |

---

## Escenas — Estructura de Nodos

### `main.tscn`
```
Main (Node2D) [script: game_startup.gd]
```

### `player.tscn`
```
Player (CharacterBody2D) [script: movement_controller.gd] [group: "player"]
├── Sprite2D (personaje-sin-fondo.png)
└── CollisionShape2D (CapsuleShape2D: radio 113, altura 310)
```

### `level_manager.tscn` (Autoload)
```
LevelManager (Node) [script: level_manager.gd]
├── CheckpointSystem (Node) [script: checkpoint_system.gd]
├── TransitionAnimator (Node) [script: transition_animator.gd]
└── SceneLoader (Node) [script: scene_loader.gd]
```

### `floor_1.tscn`
```
Floor1 (Node2D)
├── Ground (StaticBody2D) [pos: 2500, 620]
│   ├── CollisionShape2D (Rect 5000x32)
│   └── GroundSprite (ColorRect verde)
├── Player (instancia de player.tscn) [pos: 100, 500]
│   └── Camera2D (Follow_Camera: zoom (1,1), offset (0,0), rotación 0.0)
├── Checkpoint1 (instancia checkpoint_marker.tscn) [pos: 1650, 580]
├── Checkpoint2 (instancia checkpoint_marker.tscn) [pos: 3300, 580]
├── SublevelEntry (TransitionTrigger) [pos: 2500, 550] → chase_1
└── LevelEnd (TransitionTrigger) [pos: 4800, 550] → NEXT_FLOOR
```

### `entre_nivel.tscn`
```
EntreNivel (Node2D)
├── Ground (StaticBody2D) [pos: 400, 400]
│   ├── CollisionShape2D (Rect 800x32)
│   └── GroundSprite (ColorRect marrón)
└── ExitTrigger (Area2D/TransitionTrigger) [pos: 700, 350] → NEXT_FLOOR
    ├── CollisionShape2D (Rect 64x64)
    └── ExitLabel ("EXIT")
```

### `sublevel_chase_1.tscn`
```
SublevelChase1 (Node2D)
├── Ground (StaticBody2D) [pos: 1000, 400]
│   ├── CollisionShape2D (Rect 2000x32)
│   └── GroundSprite (ColorRect púrpura)
└── ExitArea (Area2D/SublevelExitTrigger) [pos: 1900, 350]
    └── CollisionShape2D (Rect 64x128)
```

### `checkpoint_marker.tscn`
```
CheckpointMarker (Area2D) [script: checkpoint_marker.gd]
├── CollisionShape2D (Rect 32x64)
├── CheckpointFlag (Sprite2D)
└── AnimationPlayer [anim: "wave" - rotación oscilatoria 0.8s]
```

---

## Sistemas Pendientes de Implementación

Según el GDD, los siguientes sistemas aún no están implementados:

| Sistema | Estado | Notas |
|---------|--------|-------|
| ❌ Combate melee | No implementado | Ataque cuerpo a cuerpo del jugador |
| ❌ Enemigos | No implementado | Tiers 0.5–15, IA de patrullaje/persecución |
| ❌ Armadura M | No implementado | Inmunidad a pisotón en ciertos enemigos |
| ❌ Pisotón (daño) | Parcial | Bounce implementado, falta daño a enemigos |
| ❌ HP / Daño | No implementado | Sistema de vida y daño del jugador |
| ❌ EXP / Niveles | No implementado | Progresión y level up |
| ❌ Tokens | No implementado | Moneda de exploración, bloques golpeables |
| ❌ Tienda | No implementado | Compra de armas/armaduras/botas |
| ❌ Equipamiento | No implementado | Armas, armaduras, botas con efectos |
| ❌ Fantasmita | No implementado | Aliado flotante con artefactos |
| ❌ Jefes | No implementado | Mini-jefes y jefes mayores (pisos 5/10/15) |
| ❌ HUD | No implementado | Corazones, tokens, marco pixel art |
| ❌ Subnivel persecución (mecánica) | Parcial | Escena base existe, falta la esfera perseguidora |
| ❌ Subnivel precisión (mecánica) | Placeholder | Solo nodo raíz vacío |
| ❌ Subnivel infiltración | No existe | Sin escena ni mecánica |
| ❌ Subnivel puzzle | No existe | Sin escena ni mecánica |
| ✅ Movimiento jugador | Completo | Con coyote, buffer, variable jump, stomp bounce |
| ✅ Sistema de niveles | Completo | Carga, transiciones, máquina de estados |
| ✅ Checkpoints | Completo | Automáticos al 33%/66%, soporte subniveles |
| ✅ Cámara | Completo | `Camera2D` estándar que sigue al jugador (sin cambios de perspectiva) |
| ✅ Transiciones | Completo | Animadas 1.5s con tipos visuales |
| ✅ Guardado/Carga | Completo | FloorProgressData persistente |
| ✅ Entre-nivel | Funcional | Zona básica con trigger de salida |

---

## Configuración del Motor

- **Physics Engine 3D:** Jolt Physics
- **Rendering:** OpenGL Compatibility (D3D12 en Windows)
- **Window Stretch:** canvas_items / expand
- **Gravedad 2D:** Default del proyecto (980 px/s²)

---

## Testing

- Framework: **GdUnit4** (`.gdunit4.cfg` presente)
- Directorio: `test/movement/` (preparado, sin tests escritos aún)
- Las funciones estáticas en `MovementController` están diseñadas para ser testeables unitariamente sin instanciar nodos

---

## Resumen del Diseño del Juego

**Torchic** es un platformer 2D con progresión RPG de 15 pisos. El jugador avanza por niveles laterales lineales con subniveles temáticos (persecución, infiltración, puntería, puzzles), todos con una cámara 2D estándar que sigue al jugador sin cambios de perspectiva. Entre cada piso hay una zona de descanso con tienda. Un fantasmita aliado acompaña al jugador y puede equiparse con artefactos de combate.

La economía se divide en EXP (por combate, sube stats) y Tokens (exploración, compra equipo). Los enemigos escalan en 15 tiers con Armadura M como mecánica de combate obligatorio melee.
