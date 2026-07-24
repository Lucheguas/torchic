# Requirements Document

## Introduction

Esta especificación describe la eliminación de la mecánica de cambio de cámara (cambio de
perspectiva por tipo de subnivel) del proyecto Godot 4 "torchic". El objetivo es dejar el
juego como un platformer 2D lineal simple, con una cámara 2D estándar que sigue al jugador
sin alterar zoom, offset ni rotación en función del subnivel.

El alcance cubre:
- Eliminación del componente `CameraController` y su script.
- Eliminación de las referencias, señales y llamadas a cambio de perspectiva en `LevelManager`.
- Eliminación del tipo de subnivel (`SubLevelType`) que solo existe para seleccionar perspectivas
  de cámara, conservando el resto del sistema de subniveles (carga de escena, transiciones,
  checkpoints) como flujo lineal.
- Conservación de una cámara 2D estándar que sigue al jugador.
- Actualización de la documentación afectada.
- Garantía de que el proyecto sigue cargando sin errores y que las pruebas existentes siguen pasando.

El alcance NO incluye rediseñar el sistema de niveles, transiciones o checkpoints más allá de lo
necesario para eliminar limpiamente la mecánica de cámara.

## Glossary

- **Camera_Switching**: Mecánica que cambia zoom, offset y/o rotación de la cámara según el
  tipo de subnivel activo.
- **Camera_Controller**: Componente actual (`scripts/level_system/camera_controller.gd`,
  `class_name CameraController`) responsable de `Camera_Switching`. Se elimina en esta especificación.
- **Follow_Camera**: Nodo `Camera2D` estándar, hijo del `Player`, que sigue al jugador sin
  cambios de perspectiva.
- **Level_Manager**: Autoload singleton (`scripts/level_system/level_manager.gd`) que orquesta
  el flujo de niveles, subniveles, checkpoints y transiciones.
- **SubLevelConfig**: Recurso (`scripts/level_system/data/sublevel_config.gd`) que describe un
  subnivel (id, escena, transición, límite de tiempo).
- **SubLevelType**: Enumeración de tipos de subnivel (`CHASE`, `INFILTRATION`,
  `PRECISION_AIMING`, `ENVIRONMENTAL_PUZZLE`) que existe únicamente para seleccionar una
  perspectiva de cámara. Se elimina en esta especificación.
- **Player**: Nodo `CharacterBody2D` controlado por el jugador.
- **Project_Documentation**: Conjunto de documentos del proyecto que describen la mecánica de
  cámara: `PROYECTO_COMPLETO.md`, `Game Design Document GDD - Platformer Core System v2.md`,
  `mapa_1_tutorial_spec.md`.
- **Test_Suite**: Conjunto de pruebas existentes bajo `test/` ejecutadas con el framework de
  pruebas configurado del proyecto (gdUnit4).

## Requirements

### Requirement 1: Eliminación del componente Camera_Controller

**User Story:** Como desarrollador, quiero eliminar el componente Camera_Controller, para que
el proyecto ya no contenga lógica de cambio de perspectiva de cámara.

#### Acceptance Criteria

1. THE Project SHALL no contener el archivo `scripts/level_system/camera_controller.gd`, de modo que
   no aparezca en el sistema de archivos del proyecto ni en el panel FileSystem del editor de Godot.
2. THE Project SHALL no contener el archivo de metadatos `.uid` asociado
   (`scripts/level_system/camera_controller.gd.uid`) en el sistema de archivos del proyecto.
3. THE Project SHALL no contener el nodo con nombre `CameraController` en la escena
   `scenes/level_system/level_manager.tscn`.
4. THE Project SHALL no contener ninguna declaración `ext_resource` que referencie
   `res://scripts/level_system/camera_controller.gd` en la escena `scenes/level_system/level_manager.tscn`.
5. WHEN el proyecto se abre en el editor de Godot, THE Project SHALL cargar la escena
   `scenes/level_system/level_manager.tscn` sin generar errores de recurso faltante ni advertencias
   que referencien `CameraController` o `camera_controller.gd`.

### Requirement 2: Level_Manager sin lógica de cambio de cámara

**User Story:** Como desarrollador, quiero que Level_Manager no contenga referencias ni llamadas
al cambio de perspectiva, para que el flujo de niveles funcione sin la mecánica de cámara.

#### Acceptance Criteria

1. THE Level_Manager SHALL excluir la referencia `@onready var camera_controller`.
2. THE Level_Manager SHALL excluir la conexión de la señal `camera_ready` y el manejador
   `_on_camera_ready`.
3. WHEN el jugador entra en un subnivel, THE Level_Manager SHALL instanciar la escena del subnivel,
   establecer el estado `PLAYING_SUBLEVEL`, rehabilitar la entrada del jugador y emitir
   `sublevel_entered`, sin invocar `apply_sublevel_perspective`.
4. WHEN el jugador sale de un subnivel, THE Level_Manager SHALL descargar la escena del subnivel,
   establecer el estado `PLAYING_MAIN_LEVEL`, rehabilitar la entrada del jugador y emitir
   `sublevel_completed`, sin invocar `reset_to_main_level`.
5. WHEN se carga un piso y el Player tiene un nodo `Camera2D`, THE Level_Manager SHALL activarlo como
   cámara actual sin invocar `setup_camera` del Camera_Controller.
6. THE Level_Manager SHALL excluir toda llamada a `setup_camera`, `apply_sublevel_perspective` y
   `reset_to_main_level`.

### Requirement 3: Conservación de la Follow_Camera estándar

**User Story:** Como jugador, quiero que la cámara siga al personaje de forma estándar, para
poder ver el nivel mientras me desplazo de forma lineal.

#### Acceptance Criteria

1. THE floor_1 scene SHALL contener exactamente un nodo `Camera2D` hijo directo del `Player`, con la
   propiedad `enabled = true` de modo que quede activo como cámara actual al cargar la escena.
2. WHILE el juego está en un piso o subnivel, THE Follow_Camera SHALL mantener zoom `Vector2(1, 1)`,
   offset `Vector2(0, 0)` y rotación `0.0`.
3. WHEN se carga un piso y el Player no tiene un nodo `Camera2D` hijo, THE Level_Manager SHALL crear,
   dentro del mismo frame de la carga, un nodo `Camera2D` hijo directo del Player con zoom
   `Vector2(1, 1)`, offset `Vector2(0, 0)` y rotación `0.0`, y activarlo como cámara actual
   (`enabled = true`).
4. IF al cargar un piso el Level_Manager no puede crear o activar el nodo `Camera2D` (por ejemplo, el
   nodo Player no existe o no está en el árbol de escena), THEN THE Level_Manager SHALL registrar un
   mensaje de error indicando la causa del fallo y SHALL conservar los nodos existentes del Player
   sin eliminarlos.

### Requirement 4: SubLevelConfig sin tipo de subnivel ligado a cámara

**User Story:** Como desarrollador, quiero eliminar el atributo de tipo de subnivel ligado a la
perspectiva de cámara, para que la configuración de subniveles no dependa de la mecánica eliminada.

#### Acceptance Criteria

1. THE SubLevelConfig SHALL excluir la enumeración `SubLevelType`.
2. THE SubLevelConfig SHALL excluir el export `sublevel_type`.
3. THE Project SHALL conservar en SubLevelConfig los campos `sublevel_id`, `scene_path`,
   `transition_type`, `has_time_limit` y `time_limit_seconds`.
4. WHEN `validate(parent_floor_id)` se invoca sobre un SubLevelConfig cuyos `sublevel_id` y
   `scene_path` no están vacíos, cuyo `scene_path` referencia un recurso existente, y donde
   `has_time_limit` es false o `time_limit_seconds` es mayor que 0.0, THE SubLevelConfig SHALL
   devolver un array de errores vacío.
5. IF `sublevel_id` está vacío cuando se invoca `validate(parent_floor_id)`, THEN THE SubLevelConfig
   SHALL incluir en el array devuelto un mensaje de error que identifique el `parent_floor_id` e
   indique que `sublevel_id` está vacío.
6. IF `scene_path` está vacío, o referencia un recurso que no existe, cuando se invoca
   `validate(parent_floor_id)`, THEN THE SubLevelConfig SHALL incluir en el array devuelto un mensaje
   de error que identifique el `parent_floor_id`, el `sublevel_id` y la condición del `scene_path`
   (vacío o inexistente).
7. IF `has_time_limit` es true y `time_limit_seconds` es menor o igual que 0.0 cuando se invoca
   `validate(parent_floor_id)`, THEN THE SubLevelConfig SHALL incluir en el array devuelto un mensaje
   de error que identifique el `parent_floor_id` y el `sublevel_id` e indique que `time_limit_seconds`
   no es válido.

### Requirement 5: Limpieza de recursos y escenas que referencian el tipo de subnivel

**User Story:** Como desarrollador, quiero que las escenas y recursos existentes no referencien el
tipo de subnivel eliminado, para que carguen sin propiedades inválidas.

#### Acceptance Criteria

1. THE floor_1 scene SHALL excluir toda asignación de la propiedad `sublevel_type` en cada uno de sus
   recursos `SubLevelConfig`.
2. THE level_registry resource SHALL excluir toda asignación de la propiedad `sublevel_type` en cada
   uno de sus recursos `SubLevelConfig` (incluidos los recursos referenciados por cada `LevelConfig`).
3. WHEN se carga la escena `floor_1` o el recurso `level_registry` en el editor de Godot, THE Project
   SHALL completar la carga sin emitir advertencias ni errores de propiedad `sublevel_type` inexistente.
4. WHEN se carga la escena `floor_1` o el recurso `level_registry`, THE Project SHALL conservar en
   cada recurso `SubLevelConfig` los valores de `sublevel_id`, `scene_path`, `transition_type`,
   `has_time_limit` y `time_limit_seconds` sin alteración.
5. IF un recurso `SubLevelConfig` de la escena `floor_1` o del recurso `level_registry` conserva una
   asignación de la propiedad `sublevel_type`, THEN THE Project SHALL emitir una advertencia que
   indique la existencia de una propiedad inexistente e ignorar dicha asignación conservando el resto
   de las propiedades del recurso.

### Requirement 6: Actualización de la documentación del proyecto

**User Story:** Como desarrollador, quiero que la documentación refleje la ausencia de la mecánica
de cambio de cámara, para que la documentación sea coherente con el código.

#### Acceptance Criteria

1. THE Project_Documentation SHALL excluir las descripciones del componente Camera_Controller,
   incluyendo los identificadores `CameraController` y `camera_controller.gd`, en los documentos
   `PROYECTO_COMPLETO.md`, `Game Design Document GDD - Platformer Core System v2.md` y
   `mapa_1_tutorial_spec.md`.
2. THE Project_Documentation SHALL excluir las descripciones de la mecánica de cambio de perspectiva
   de cámara (subniveles con cambio de cámara) en dichos documentos.
3. THE Project_Documentation SHALL describir la Follow_Camera como un nodo `Camera2D` hijo del
   `Player` con zoom `Vector2(1, 1)`, offset `Vector2(0, 0)` y rotación `0.0`, que sigue al jugador
   sin cambios de perspectiva.
4. WHERE la documentación describa los campos de SubLevelConfig, THE Project_Documentation SHALL
   excluir el campo `sublevel_type` y la enumeración `SubLevelType` de dichas descripciones.

### Requirement 7: Integridad del proyecto y pruebas

**User Story:** Como desarrollador, quiero que el proyecto compile y las pruebas sigan pasando tras
la eliminación, para asegurar que el refactor no introduce regresiones.

#### Acceptance Criteria

1. WHEN el proyecto se carga en el editor de Godot, THE Project SHALL cargar todos los scripts con
   cero errores de análisis (parse errors) en el panel de salida relacionados con símbolos de cámara
   eliminados (`CameraController`, `SubLevelType`, `camera_controller`).
2. WHEN se ejecuta la Test_Suite con gdUnit4, THE Test_Suite SHALL completar con el 100% de los casos
   existentes en estado aprobado, cero casos fallidos y cero casos con error de ejecución.
3. IF una prueba existente referencia símbolos de cámara eliminados, THEN THE Test_Suite SHALL
   actualizar dicha prueba para eliminar la referencia, conservando la intención original de la
   prueba y manteniéndola en estado aprobado.
4. THE Test_Suite SHALL conservar el mismo número de casos de prueba existentes antes de la
   eliminación, sin suprimir casos para lograr el estado aprobado.
