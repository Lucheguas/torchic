# Torchic — Consideraciones y configuraciones para nuevas implementaciones

Guía práctica de todo lo que hay que tener en cuenta **antes de dar por terminada** cualquier
implementación nueva en el proyecto, ya sea una mecánica, un enemigo, un arma, un trigger o un
nivel/piso completo. Complementa a `.kiro/steering/project-architecture.md` (arquitectura y
convenciones de código); este documento se centra en la **configuración concreta** (project.godot,
grupos, capas, señales, wiring del `LevelManager`) que hay que respetar para que lo nuevo funcione
integrado con el resto del sistema.

> Regla de oro del proyecto: **simplicidad sobre generalidad.** No añadas abstracciones, flags ni
> validaciones "por si acaso". Si algo huele a sobreingeniería, cuestiónalo antes de implementarlo.

---

## 1. Configuración global del proyecto (`project.godot`)

Estos valores condicionan cómo se comporta todo lo demás. Si tu implementación depende de ellos o
los cambia, documéntalo.

### Motor y render
- **Godot 4.7**, renderer **GL Compatibility** (`renderer/rendering_method = "gl_compatibility"`).
- Driver en Windows: `d3d12`.
- **Filtro de textura por defecto: `0` (Nearest).** Es lo que mantiene el look pixel art. No lo
  cambies a lineal en assets de píxeles; si un asset necesita filtrado distinto, ajústalo por
  recurso, no globalmente.
- Física 3D usa Jolt, pero el juego es 2D: la que importa es
  **`physics/2d/default_gravity`**. Tanto `MovementController` como `EnemyBasic` la leen vía
  `ProjectSettings.get_setting("physics/2d/default_gravity")`. Un enemigo o mecánica nueva que use
  gravedad debe leerla de ahí, no hardcodearla.

### Ventana / resolución
- Viewport base: **480 × 270** (`window/size/viewport_width/height`).
- Ventana real: **1280** de ancho (`window_width_override`).
- Stretch mode: **`canvas_items`**.
- Consecuencia: todo el diseño de niveles trabaja en coordenadas de mundo, no de píxel de pantalla.
  Ten presente esta escala al colocar plataformas, cámaras y UI.

### Escena principal
- `run/main_scene = "res://scenes/main.tscn"`. `main.tscn` corre `game_startup.gd`, que espera un
  frame y llama a `LevelManager.start_game(false)`.

### Autoloads
- **Único autoload: `LevelManager`** (`res://scenes/level_system/level_manager.tscn`).
- No añadas autoloads salvo que el servicio sea genuinamente global. Prefiere referencias directas y
  señales.

### Input map (acciones existentes)
Toda mecánica que lea input debe usar (o añadir) **acciones nombradas**, nunca teclas hardcodeadas.

| Acción | Teclas | Uso actual |
|---|---|---|
| `move_left` | `A`, `←` | Movimiento horizontal |
| `move_right` | `D`, `→` | Movimiento horizontal |
| `jump` | `W`, `↑`, `Espacio` | Salto (variable, coyote, buffer, doble salto) |
| `attack` | `G` | Dispara `$MeleeAttack.trigger(facing)` |

Si añades una mecánica con input nuevo (dash, agacharse, interactuar…):
1. Registra la acción en `project.godot` → `[input]` (idealmente desde el editor, Project Settings →
   Input Map).
2. Léela con `Input.is_action_just_pressed(...)` / `Input.get_axis(...)`.
3. Añádela a la tabla de arriba en este documento.

---

## 2. Grupos, capas de colisión y señales (contratos entre sistemas)

### Grupo `player` (crítico)
El contrato central del juego: **el jugador debe estar en el grupo `"player"`**. Todos estos
sistemas lo verifican y no harán nada si el grupo falta:
- `PlayerTrigger` (y subclases: transición, checkpoint, salida de sublevel).
- `KillZone`.
- `EnemyBasic.$StompArea`.

Al crear cualquier zona/área que reaccione al jugador, filtra siempre por:
```gdscript
if not (body is CharacterBody2D and body.is_in_group("player")):
    return
```

### Capas de colisión
- Actualmente el proyecto **usa la capa/máscara por defecto (layer 1)** en todos los cuerpos: el
  jugador, enemigos (`CharacterBody2D`), suelo/plataformas (`StaticBody2D`) y las áreas (`Area2D`)
  no declaran capas personalizadas. En la práctica "todo colisiona con todo" y el filtrado real se
  hace por **grupo** y por **tipo** (`is BaseEnemy`, `is_in_group("player")`).
- Si en el futuro necesitas separar colisiones (p. ej. proyectiles que atraviesan enemigos pero no
  paredes), define capas nombradas en Project Settings → Layer Names → 2D Physics **antes** de
  asignarlas, y documenta el esquema aquí. No repartas números de capa mágicos por las escenas.

### Detección de daño y stomp (decisiones vigentes, no revertir)
- **Contacto jugador→enemigo** (`MovementController._check_enemy_contact_damage`): tras
  `move_and_slide()`, recorre `get_slide_collision(i)`. Si el colisionador es `BaseEnemy` y la normal
  **no** apunta hacia arriba (`normal.y > -0.7`), el jugador muere. Los golpes desde arriba se
  ignoran aquí; los resuelve el `StompArea` del enemigo.
- **Stomp** (`EnemyBasic._on_stomp_area_body_entered`): se detecta por **posición**
  (`body.global_position.y < global_position.y`), **no** por `velocity.y > 0`. La velocidad puede
  quedar en cero por la resolución de colisión antes de que dispare la señal del área.
- **`_previous_velocity_y` se captura ANTES de `move_and_slide()`** para detectar aterrizajes.

### Señales (mecanismo público de observación)
- Nombres en **pasado**: `landed`, `stomp_bounced`, `checkpoint_activated`, `floor_started`,
  `marker_activated`, `triggered`, etc.
- Los sistemas se comunican por señales + setters, no por eventos globales ad-hoc.
- **Convención de wiring del `LevelManager` (importante para niveles):** el manager descubre nodos
  del nivel por *duck typing*, no por tipo concreto. Recorre las `Area2D` del nivel y:
  - Conecta como **fin de piso** cualquier `Area2D` que tenga señal `triggered` y una propiedad
    `target_type == 2` (NEXT_FLOOR).
  - Conecta como **checkpoint** cualquier `Area2D` que tenga el método `activate()` y la señal
    `marker_activated`.
  - Si creas un trigger nuevo que deba integrarse con el manager, respeta esas firmas (señal
    `triggered(self)` + export `target_type`, o método `activate()` + señal `marker_activated`).

---

## 3. Checklist: escena del jugador (`player.tscn`)

Si tocas al jugador o creas una variante, la escena debe cumplir el contrato que asume el código:

- Raíz **`CharacterBody2D`** con `MovementController` (`class_name MovementController`).
- Está en el grupo **`player`**.
- Hijos requeridos por el script:
  - **`$Sprite2D`** — el controller lee su escala en `_ready()` (`_base_sprite_scale`) y la respeta
    al animar (multiplica, nunca resetea a 1.0). Si el sprite tiene escala en el `.tscn`, esa escala
    se conserva.
  - **`$MeleeAttack`** — nodo `MeleeAttack` (Area2D) con un `MeleeWeapon` asignado en el Inspector.
  - **`Camera2D`** — hija del jugador, zoom `(1,1)`, offset `(0,0)`, rotación `0`. Si la escena la
    omite, `LevelManager._setup_player_and_camera()` crea una y la hace `current`. No hay
    `CameraController`.
- Los parámetros de tuning (velocidad, salto, gravedad, coyote, buffer, stomp, landing) son
  `@export` agrupados con `@export_group`. Ajusta desde el Inspector, no hardcodees.

---

## 4. Checklist: nueva mecánica de jugador

1. ¿Necesita input? Registra la acción en el Input Map (sección 1) y actualiza este doc.
2. Implementa la lógica en `MovementController` (o en un componente por composición si es un
   subsistema con estado propio, estilo `ModifierStack`). **No** heredes salvo que ya existan 2+
   usuarios reales.
3. **Timers = floats decrementados en `_physics_process`**, no nodos `Timer`.
4. Si es un modificador (velocidad, salto, etc.), añádelo a `ModifierStack` con un **setter que
   clampee el rango** y expón un setter público en `MovementController` que delegue. Clamping de
   rangos numéricos sí; try/catch y null-checks innecesarios, no.
5. Si otros sistemas deben enterarse, emite una **señal en pasado**; no llames a otros nodos
   directamente si una señal basta.
6. Respeta el orden del loop físico existente (`_handle_*` → captura `_previous_velocity_y` →
   `move_and_slide()` → chequeos post-colisión).
7. Tests: propiedades matemáticas puras (clamping, interpolación) con fuzzers de GdUnit4 (≥100
   iteraciones); casos edge concretos como unit tests. No cobertura por cobertura.

---

## 5. Checklist: nuevo enemigo

1. Hereda de **`BaseEnemy`** (`CharacterBody2D`, tiene `hp` y `take_damage(amount)` que hace
   `queue_free()` al llegar a 0). Declara `class_name`.
2. La escena del enemigo, si es "stompeable", necesita un hijo **`$StompArea` (Area2D)** y conectar
   `body_entered` en `_ready()`.
3. Detección de pisotón **por posición** (jugador por encima), nunca por `velocity.y`. Al recibir el
   stomp: `body.notify_stomp_hit()` + `take_damage(1)`.
4. Gravedad leída de `physics/2d/default_gravity`.
5. Parámetros de patrulla/comportamiento como `@export` (`patrol_speed`, `patrol_distance`, …).
6. Colocación en el nivel: instanciar la escena del enemigo bajo un nodo agrupador (p. ej.
   `Enemies`) y ajustar `position` / exports por instancia (ver `floor_1.tscn`).
7. Métodos virtuales de override usan prefijo `_` (`_update_behavior`, etc.) si añades una jerarquía.

---

## 6. Checklist: nueva arma

- Datos serializables → **`Resource` (`MeleeWeapon`)**: `weapon_name`, `damage`. Sin lógica activa.
- La lógica de golpeo vive en un nodo **`MeleeAttack` (Area2D)**:
  - `monitoring`/`visible` en `false` hasta que se dispara.
  - `trigger(facing)` orienta la hitbox (`position.x`, `scale.x`) según el `flip_h` del sprite y la
    activa durante `attack_duration`.
  - Aplica `weapon.damage` vía `BaseEnemy.take_damage` y usa `_already_hit` para no golpear al mismo
    enemigo dos veces por swing.
- El arma equipada se asigna en el Inspector del `$MeleeAttack` del jugador. No crees un sistema de
  inventario/equipamiento hasta que exista un segundo caso real.

---

## 7. Checklist: nuevo trigger / zona

- Si reacciona **una vez** al jugador: hereda de **`PlayerTrigger`** (Area2D). Sobrescribe
  `_on_player_entered(body)`; la base ya filtra por grupo `player`, dispara una sola vez y se
  desconecta.
- Subclases existentes como referencia: `TransitionTrigger`, `SublevelExitTrigger`,
  `CheckpointMarker`.
- Para integrarte con el `LevelManager` (sección 2 → wiring):
  - **Fin de piso / cambio de escena**: emite `triggered(self)` y expón
    `@export var target_type` con valor `NEXT_FLOOR (2)`.
  - **Checkpoint**: expón método `activate()` y señal `marker_activated`.
- Zonas de muerte (pits/abismos): usa **`KillZone` (Area2D)**. Delega en
  `LevelManager.handle_player_death()`; **no** muta al jugador directamente. Verifica que el autoload
  exista antes de llamar (como hace `KillZone._has_level_manager()`).

---

## 8. Checklist: nuevo nivel / piso

Un piso funciona cuando (a) su **escena** cumple el contrato de nodos y (b) está **registrado** en el
`LevelRegistry`.

### 8.1 La escena del piso (`res://scenes/levels/floor_N.tscn`)
Mira `floor_1.tscn` como plantilla. Debe incluir:
- **Una instancia del jugador** (`player.tscn`) colocada en el spawn, en el grupo `player`.
  (`LevelManager` usa `get_tree().get_first_node_in_group("player")`; su `global_position` inicial
  es el punto de respawn base, así que colócalo bien desde el arranque, no lo muevas después de
  cargar.)
- **Geometría de colisión**: suelo y plataformas como `StaticBody2D` + `CollisionShape2D`
  (+ `ColorRect`/tilemap para lo visual). Capa por defecto.
- **`KillZone` (Area2D)** cubriendo pits y el fondo del mundo.
- **Checkpoints**: instancias de `checkpoint_marker.tscn`. Se autoactivan al contacto y se conectan
  solos al manager. Además, `CheckpointSystem` activa checkpoints por **progreso horizontal** al
  **33 %** y **66 %** del mapa (índices 0 y 1), usando `map_length_px` de la config.
- **Fin de piso**: un `TransitionTrigger` con `target_type = 2` (NEXT_FLOOR) al final del recorrido.
  Al entrar el jugador, dispara `complete_floor()`.
- Fondo con `ParallaxBackground`/`ParallaxLayer` si aplica (opcional, estético).

### 8.2 Registrar el piso (`res://resources/level_registry.tres`)
Añade un `LevelConfigData` al array `levels` con:
- **`floor_id`** (>0, único).
- **`scene_path`** (debe existir; `validate()` lo comprueba con `ResourceLoader.exists`).
- **`map_length_px`** (por defecto 5000): define el 100 % de progreso para los checkpoints
  automáticos. Ajústalo al ancho real jugable del piso.
- **`phase`** (`FOREST` ≤5, `CAVE` ≤10, `LABORATORY` >10) y **`boss_type`**.
- **`entre_nivel_scene_path`** (por defecto `res://scenes/entre_nivel.tscn`).
- `sublevels` (ver sección 10: actualmente **deshabilitados**, déjalo vacío).
- **Pisos de jefe mayor: 5, 10 y 15 deben tener `boss_type = MAJOR`** (lo valida `validate()`).

### 8.3 Cómo llega el jugador al piso
- Flujo normal: al completar un piso, `complete_floor()` reproduce transición, carga
  `entre_nivel`, y al salir de ahí `exit_entre_nivel()` hace `load_floor(current_floor_id + 1)`.
- **Fallback (decisión vigente):** si se pide un `floor_id` sin config, `load_floor()` cae a **piso
  1** y reescribe el save para mantenerlo consistente. Evita pantallas vacías por saves con pisos
  inexistentes.
- **Boot standalone (F6 / test):** `LevelManager._bootstrap_standalone_scene()` detecta un piso ya
  en el árbol que el manager no cargó, resuelve el jugador y la cámara, inicializa el
  `CheckpointSystem` con la spawn position y arma el pipeline de muerte **una sola vez**. Por eso un
  `floor_N.tscn` corre bien con F6 sin pasar por `main.tscn`. Requisito: el jugador debe estar en el
  grupo `player` y ser hijo/descendiente propietario de la escena.

### 8.4 Carga de escenas
- Toda carga/descarga pasa por **`SceneLoader`** (asíncrono, `ResourceLoader.load_threaded_*`,
  1 reintento). No instancies pisos a mano en producción; usa `LevelManager.load_floor()`.
- `unload_scene()` **quita del árbol inmediatamente** y luego `queue_free()`, para que los nodos
  salgan de sus grupos ese mismo frame y no haya dos players solapados un frame.

---

## 9. Escena "entre niveles" (`entre_nivel.tscn`)
- Es la escena puente entre pisos. **Embebe su propio Player**; el manager la cablea con
  `_setup_player_and_camera()` al cargarla.
- Su salida es una `Area2D` con `target_type = 2` (NEXT_FLOOR) que dispara `exit_entre_nivel()` →
  carga el siguiente piso. Durante la estancia, el manager **precarga** la escena del piso siguiente.

---

## 10. Estado deshabilitado actualmente (NO construir encima sin reactivar)
- **Sublevels desactivados para testing.** `TransitionTrigger` con `target_type = SUBLEVEL` no hace
  nada; `enter_sublevel()` y `complete_sublevel()` son *stubs* vacíos; `SublevelExitTrigger` no
  llama a nada. Toda la lógica real está comentada en `level_manager.gd`.
  - Si tu feature necesita sublevels, primero **reactiva y prueba** ese camino (descomentar +
    volver a habilitar `TransitionTrigger.SUBLEVEL`), no asumas que funciona.
- **Persistencia de estado del jugador**: `FloorProgressData.capture_player_state()` y
  `restore_player_state()` son *stubs* vacíos. Si añades HP/tokens/exp persistentes que deban
  sobrevivir a transiciones o respawn, tendrás que implementarlos.

---

## 11. Guardado / progreso (`FloorProgressData`)
- Se persiste en **`user://floor_progress.tres`**.
- **Cada arranque empieza de cero**: `game_startup.gd` llama a `start_game(false)`, que ignora el
  save y crea un `FloorProgressData` nuevo (piso 1). El save solo se leería con `start_game(true)`
  (feature "continuar" futura).
- Se guarda al completar piso (`update_floor_completed`) y al activar checkpoints
  (`_on_checkpoint_activated`). `current_floor` se topa en 15.
- Si añades campos persistentes, hazlos `@export` en `FloorProgressData` y guárdalos con
  `save_to_disk()`.

---

## 12. Testing (GdUnit4)
- Config en `.gdunit4.cfg`: raíz de tests **`test/`**, `report_orphan_nodes = true`,
  `test_timeout = 60`, `stop_on_failure = false`.
- **Property-based tests** con los fuzzers de GdUnit4, **≥100 iteraciones**, para propiedades
  matemáticas puras (clamping de `ModifierStack`, interpolación de velocidad, aritmética de daño,
  `calculate_progress` de checkpoints).
- **Unit tests** para casos edge concretos (fallback de piso, pipeline de muerte, activación de
  checkpoints por progreso). No tests que solo reafirman al compilador (verificar que existe un
  `class_name` sobra).
- **Smoke test obligatorio:** al menos uno que valide que `floor_1.tscn` (y cualquier piso nuevo)
  **carga sin errores** tras un refactor.
- Al añadir mecánica o piso: escribe test de la propiedad/caso edge relevante y corre la suite antes
  de dar por hecho el trabajo.

---

## 13. Estilo y convenciones (recordatorio rápido)
- **GDScript exclusivo** (no C#). **Tabs** para indentar.
- `class_name` en toda clase relevante; `snake_case` (vars/func), `PascalCase` (`class_name`),
  `SCREAMING_SNAKE_CASE` (constantes).
- Type hints en firmas y en variables cuyo tipo no sea obvio.
- Docstrings con `##` solo cuando aporten algo no obvio. Comentarios explican el **porqué**.
- Miembros privados con prefijo `_`. La API pública son métodos sin prefijo + señales.
- `push_error` / `push_warning` para diagnósticos; nada de `print` de debug ni logging/telemetría
  sin necesidad concreta.
- Cada script `.gd` tiene su `.gd.uid`; las escenas referencian por `uid`. Deja que Godot los
  gestione (crea/mueve archivos desde el editor cuando puedas).

---

## 14. Decisiones vigentes que no se relitigan
1. GDScript, no C#.
2. Timers = floats en `_physics_process`, no nodos `Timer`.
3. Movimiento horizontal **instantáneo** (sin aceleración/desaceleración).
4. `_previous_velocity_y` se captura **antes** de `move_and_slide()`.
5. Escala del sprite del jugador vive en el `.tscn`; `_animate_walk` la **multiplica**, no la
   resetea.
6. Enemigos detectan stomp por **posición** (jugador por encima), no por `velocity.y`.
7. `LevelManager.load_floor()` cae a **piso 1** si el piso pedido no tiene config.
