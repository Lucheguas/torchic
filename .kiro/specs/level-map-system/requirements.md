# Requirements Document

## Introduction

Este documento define los requerimientos del sistema de niveles, mapas y transiciones para el platformer 2D "Torchic", desarrollado en Godot 4.7 con GDScript y renderer GL Compatibility. El sistema cubre la estructura de 15 niveles de progresión continua, checkpoints automáticos basados en distancia, subniveles con cambio de cámara y transiciones animadas, zonas de entre-nivel (tienda con Fantasmita), y la gestión de carga/descarga de escenas. Todo opera sobre un CharacterBody2D existente en un side-scroller 2D con estética pixel art.

## Glossary

- **Level_Manager**: Autoload (singleton) GDScript que orquesta la carga, descarga y transición entre niveles, subniveles y zonas de entre-nivel.
- **Level_Scene**: Escena PackedScene de Godot que representa un nivel principal completo (piso) del juego, incluyendo TileMap, enemigos y plataformas.
- **Sub_Level**: Sección especial dentro de un piso que utiliza una perspectiva de cámara diferente al nivel principal y tiene reglas de checkpoint independientes.
- **Entre_Nivel**: Zona intermedia entre pisos que funciona como tienda donde el jugador interactúa con el Fantasmita para comprar equipamiento.
- **Checkpoint_System**: Componente del Level_Manager que registra y administra las posiciones de reaparición del jugador dentro de un nivel o subnivel.
- **Active_Checkpoint**: Posición de reaparición actualmente registrada donde el jugador reaparecerá tras morir o caer al vacío.
- **Checkpoint_Marker**: Nodo Area2D colocado en el nivel que define una posición de checkpoint. Se activa automáticamente al ser alcanzado por el jugador.
- **Checkpoint_Flag**: Sprite2D hijo del Checkpoint_Marker que muestra una bandera visual. Cambia de color gris (inactivo) a verde (activo) cuando el jugador alcanza el checkpoint, proporcionando feedback visual claro.
- **Level_Progress**: Valor porcentual (0.0 a 1.0) que indica cuánto del nivel principal ha recorrido el jugador, calculado como la distancia horizontal avanzada dividida por la distancia total del mapa.
- **Transition_Trigger**: Nodo Area2D que al ser activado por el Player_Character inicia una transición hacia un subnivel, entre-nivel u otro piso.
- **Camera_Controller**: Script que gestiona la posición, zoom y rotación de la Camera2D durante el gameplay y las transiciones animadas.
- **Sub_Level_Type**: Enumeración que define los tipos de subnivel disponibles: CHASE (persecución frontal), INFILTRATION (cámara trasera), PRECISION_AIMING (riel fijo + mouse), ENVIRONMENTAL_PUZZLE (vista top-down).
- **Floor_Progress_Data**: Recurso que almacena el estado de progreso global del jugador: piso actual, checkpoints desbloqueados, subniveles completados.
- **Scene_Loader**: Componente del Level_Manager responsable de la carga asíncrona y descarga de escenas usando ResourceLoader de Godot.
- **Transition_Animation**: Secuencia visual animada de 1.5 segundos que se reproduce durante el cambio entre nivel principal y subnivel.
- **Major_Boss_Level**: Nivel especial en los pisos 5, 10 y 15 que contiene un Jefe Mayor con mecánicas únicas de combate.
- **Player_Character**: Nodo CharacterBody2D que representa al personaje controlado por el jugador.

## Requirements

### Requirement 1: Estructura de Niveles y Progresión

**User Story:** Como jugador, quiero avanzar a través de 15 niveles de dificultad progresiva con jefes mayores cada 5 pisos, para experimentar una curva de progresión clara y motivante.

#### Acceptance Criteria

1. THE Level_Manager SHALL gestionar una secuencia de 15 niveles ordenados de forma continua, identificados del piso 1 al piso 15.
2. THE Level_Manager SHALL cargar cada piso como una Level_Scene independiente que contiene un mapa principal con enemigos y plataformas.
3. WHEN el jugador completa el mapa principal de un piso, THE Level_Manager SHALL transicionar al Entre_Nivel correspondiente antes de cargar el siguiente piso.
4. WHEN el jugador se encuentra en los pisos 5, 10 o 15, THE Level_Manager SHALL cargar un Major_Boss_Level en lugar del minijefe estándar de final de piso.
5. THE Level_Manager SHALL almacenar en Floor_Progress_Data el piso más alto alcanzado por el jugador para permitir la continuación de partida.

### Requirement 2: Checkpoints en Niveles Principales

**User Story:** Como jugador, quiero que el nivel se divida automáticamente en secciones con checkpoints marcados por banderas visibles, para no perder demasiado progreso al morir y saber exactamente dónde estoy respawneando.

#### Acceptance Criteria

1. THE Checkpoint_System SHALL calcular el Level_Progress del jugador como la distancia horizontal recorrida desde el inicio del nivel dividida por la distancia horizontal total del mapa.
2. WHEN el Level_Progress del jugador alcanza o supera 0.33, THE Checkpoint_System SHALL activar el primer Checkpoint_Marker y registrarlo como Active_Checkpoint.
3. WHEN el Level_Progress del jugador alcanza o supera 0.66, THE Checkpoint_System SHALL activar el segundo Checkpoint_Marker y registrarlo como Active_Checkpoint.
4. WHEN el Player_Character muere o cae al vacío en el nivel principal, THE Checkpoint_System SHALL reposicionar al Player_Character en la posición del Active_Checkpoint más reciente.
5. IF no existe un Active_Checkpoint registrado al momento de la muerte, THEN THE Checkpoint_System SHALL reposicionar al Player_Character en la posición de inicio del nivel.
6. THE Checkpoint_System SHALL colocar los Checkpoint_Markers en posiciones de plataforma segura cercanas al 33% y 66% del recorrido horizontal del nivel.
7. EACH Checkpoint_Marker SHALL contener un Checkpoint_Flag que se muestra con color gris (modulación gris) por defecto indicando estado inactivo.
8. WHEN el Player_Character activa un Checkpoint_Marker, THE Checkpoint_Flag SHALL cambiar su color de gris a verde mediante modulación del sprite, indicando visualmente que el checkpoint fue alcanzado.
9. THE Checkpoint_Flag SHALL reproducir una animación breve de ondeo al momento de ser activada para dar feedback visual claro al jugador.

### Requirement 3: Checkpoints en Subniveles

**User Story:** Como jugador, quiero que los subniveles tengan su propio sistema de checkpoints independiente, para poder reintentarlos sin perder el progreso del piso principal.

#### Acceptance Criteria

1. WHEN el Player_Character activa un Transition_Trigger de entrada a un Sub_Level, THE Checkpoint_System SHALL registrar un checkpoint de entrada en la posición previa a la transición dentro del nivel principal.
2. WHEN el Player_Character completa un Sub_Level, THE Checkpoint_System SHALL registrar un checkpoint de salida en la posición de retorno al nivel principal.
3. WHEN el Player_Character muere dentro de un Sub_Level, THE Checkpoint_System SHALL reposicionar al Player_Character en la posición de inicio de ese Sub_Level específico.
4. WHEN el Player_Character muere dentro de un Sub_Level, THE Checkpoint_System SHALL preservar el Floor_Progress_Data del piso principal sin modificaciones.
5. THE Checkpoint_System SHALL tratar cada Sub_Level como una sección independiente que no afecta los checkpoints del 33% y 66% del nivel principal.

### Requirement 4: Transiciones Animadas a Subniveles

**User Story:** Como jugador, quiero que la entrada a subniveles tenga una animación de transición suave, para que el cambio de cámara no sea brusco ni desorientador.

#### Acceptance Criteria

1. WHEN el Player_Character activa un Transition_Trigger hacia un Sub_Level, THE Camera_Controller SHALL ejecutar una Transition_Animation con una duración de 1.5 segundos.
2. WHILE la Transition_Animation se ejecuta, THE Level_Manager SHALL deshabilitar el input del jugador para evitar acciones durante la transición.
3. WHEN la Transition_Animation finaliza, THE Level_Manager SHALL activar la escena del Sub_Level con la perspectiva de cámara correspondiente al Sub_Level_Type.
4. WHEN el Player_Character completa un Sub_Level, THE Camera_Controller SHALL ejecutar una Transition_Animation inversa de 1.5 segundos para retornar a la perspectiva del nivel principal.
5. THE Transition_Animation SHALL incluir un efecto visual que indique el tipo de transición (puerta, tubería o portal de datos) según el Transition_Trigger activado.

### Requirement 5: Subnivel Tipo Persecución (CHASE)

**User Story:** Como jugador, quiero subniveles de persecución donde corro hacia la pantalla esquivando obstáculos, para experimentar variedad y tensión en el gameplay.

#### Acceptance Criteria

1. WHEN se carga un Sub_Level de tipo CHASE, THE Camera_Controller SHALL posicionar la cámara en perspectiva frontal mostrando al Player_Character corriendo hacia la pantalla.
2. WHILE el Sub_Level tipo CHASE está activo, THE Level_Manager SHALL mover automáticamente al Player_Character hacia adelante a velocidad constante sin control del jugador sobre el avance.
3. WHILE el Sub_Level tipo CHASE está activo, THE Level_Manager SHALL permitir al jugador controlar el movimiento lateral y el salto para esquivar obstáculos.
4. WHEN el Player_Character colisiona con un obstáculo o cae al vacío en el Sub_Level tipo CHASE, THE Checkpoint_System SHALL aplicar las reglas de muerte en subnivel.
5. THE Level_Manager SHALL finalizar el Sub_Level tipo CHASE cuando el Player_Character alcanza el punto de salida definido al final del recorrido.

### Requirement 6: Subnivel Tipo Infiltración (INFILTRATION)

**User Story:** Como jugador, quiero subniveles de infiltración con cámara trasera donde avanzo por pasillos con profundidad, para experimentar un gameplay diferente al side-scroll estándar.

#### Acceptance Criteria

1. WHEN se carga un Sub_Level de tipo INFILTRATION, THE Camera_Controller SHALL posicionar la cámara detrás del Player_Character mostrando un pasillo con profundidad.
2. WHILE el Sub_Level tipo INFILTRATION está activo, THE Level_Manager SHALL permitir al jugador controlar el movimiento hacia adelante, lateral y el salto.
3. WHILE el Sub_Level tipo INFILTRATION está activo, THE Level_Manager SHALL generar obstáculos que se aproximan de frente al Player_Character.
4. WHEN el Player_Character colisiona con un obstáculo en el Sub_Level tipo INFILTRATION, THE Checkpoint_System SHALL aplicar las reglas de muerte en subnivel.
5. THE Level_Manager SHALL finalizar el Sub_Level tipo INFILTRATION cuando el Player_Character alcanza la salida al final del pasillo.

### Requirement 7: Subnivel Tipo Apuntado de Precisión (PRECISION_AIMING)

**User Story:** Como jugador, quiero subniveles donde puedo apuntar y disparar con el mouse desde una posición fija, para tener secciones de gameplay que prueben mi puntería.

#### Acceptance Criteria

1. WHEN se carga un Sub_Level de tipo PRECISION_AIMING, THE Camera_Controller SHALL posicionar la cámara en un ángulo elevado fijo que permite al jugador ver el área de juego completa.
2. WHILE el Sub_Level tipo PRECISION_AIMING está activo, THE Level_Manager SHALL mantener al Player_Character en una plataforma fija o riel con movimiento limitado.
3. WHILE el Sub_Level tipo PRECISION_AIMING está activo, THE Level_Manager SHALL permitir al jugador apuntar con el cursor del mouse y disparar proyectiles hacia los objetivos.
4. WHEN todos los objetivos del Sub_Level tipo PRECISION_AIMING son destruidos o el tiempo límite expira, THE Level_Manager SHALL finalizar el subnivel.
5. IF un proyectil enemigo colisiona con el Player_Character o la plataforma es destruida, THEN THE Checkpoint_System SHALL aplicar las reglas de muerte en subnivel.

### Requirement 8: Subnivel Tipo Puzzles Ambientales (ENVIRONMENTAL_PUZZLE)

**User Story:** Como jugador, quiero subniveles de puzzles con vista top-down donde resuelvo acertijos de lógica, para variar el ritmo del juego con desafíos mentales.

#### Acceptance Criteria

1. WHEN se carga un Sub_Level de tipo ENVIRONMENTAL_PUZZLE, THE Camera_Controller SHALL posicionar la cámara en vista cenital (top-down) mostrando la sala completa del puzzle.
2. WHILE el Sub_Level tipo ENVIRONMENTAL_PUZZLE está activo, THE Level_Manager SHALL permitir al jugador mover al Player_Character en las cuatro direcciones cardinales.
3. WHILE el Sub_Level tipo ENVIRONMENTAL_PUZZLE está activo, THE Level_Manager SHALL permitir al jugador interactuar con bloques movibles e interruptores presionables.
4. WHEN el jugador resuelve el puzzle activando todos los interruptores requeridos, THE Level_Manager SHALL abrir la puerta de salida y finalizar el subnivel.
5. WHERE el puzzle tiene un tiempo límite definido, THE Level_Manager SHALL reiniciar el subnivel al expirar el tiempo sin resolver el puzzle.

### Requirement 9: Zona de Entre-Nivel (Tienda)

**User Story:** Como jugador, quiero una zona intermedia entre niveles donde puedo comprar equipamiento con tokens recolectados, para prepararme antes del siguiente desafío.

#### Acceptance Criteria

1. WHEN el jugador completa un nivel principal, THE Level_Manager SHALL cargar la escena del Entre_Nivel antes de proceder al siguiente piso.
2. THE Level_Manager SHALL instanciar al Fantasmita como NPC interactuable en la zona de Entre_Nivel.
3. WHEN el Player_Character interactúa con el Fantasmita en el Entre_Nivel, THE Level_Manager SHALL abrir la interfaz de tienda mostrando el equipamiento disponible y los tokens del jugador.
4. WHEN el jugador confirma la salida del Entre_Nivel, THE Level_Manager SHALL cargar la Level_Scene del siguiente piso.
5. THE Level_Manager SHALL preservar el estado completo del jugador (HP, tokens, equipamiento, nivel) durante la transición desde el Entre_Nivel al siguiente piso.

### Requirement 10: Carga y Descarga Asíncrona de Escenas

**User Story:** Como jugador, quiero que los niveles se carguen sin pausas perceptibles, para mantener la fluidez de la experiencia de juego.

#### Acceptance Criteria

1. THE Scene_Loader SHALL utilizar ResourceLoader.load_threaded_request() de Godot para iniciar la carga asíncrona de la siguiente Level_Scene.
2. WHILE una escena se carga de forma asíncrona, THE Scene_Loader SHALL consultar el progreso mediante ResourceLoader.load_threaded_get_status() sin bloquear el hilo principal.
3. WHEN la carga asíncrona de una escena finaliza con éxito, THE Scene_Loader SHALL notificar al Level_Manager que la escena está lista para ser instanciada.
4. WHEN el Level_Manager requiere transicionar a una nueva escena, THE Scene_Loader SHALL descargar la escena actual liberando los recursos de memoria mediante queue_free() en el nodo raíz de la escena anterior.
5. IF la carga asíncrona de una escena falla, THEN THE Scene_Loader SHALL registrar el error en el log y reintentar la carga una vez antes de mostrar un mensaje de error al jugador.
6. THE Scene_Loader SHALL iniciar la precarga de la siguiente escena durante el Entre_Nivel para minimizar tiempos de espera.

### Requirement 11: Gestión del Estado de Juego entre Niveles

**User Story:** Como jugador, quiero que mi progreso se conserve correctamente al transicionar entre niveles y al salir del juego, para continuar mi partida sin pérdidas.

#### Acceptance Criteria

1. THE Level_Manager SHALL mantener el Floor_Progress_Data actualizado con el piso actual, checkpoints activos y subniveles completados en cada transición.
2. WHEN el jugador transiciona entre escenas, THE Level_Manager SHALL transferir el estado del Player_Character (HP actual, tokens, EXP, equipamiento) sin pérdida de datos.
3. WHEN el jugador completa un piso, THE Level_Manager SHALL actualizar el piso más alto alcanzado en Floor_Progress_Data.
4. THE Level_Manager SHALL persistir el Floor_Progress_Data en disco usando el sistema de guardado de Godot (ResourceSaver o ConfigFile) al completar cada piso y al entrar a zonas de Entre_Nivel.
5. WHEN el jugador inicia una sesión de juego, THE Level_Manager SHALL cargar el Floor_Progress_Data persistido y posicionar al jugador en el inicio del piso más alto alcanzado o en el Entre_Nivel previo a ese piso.

### Requirement 12: Configuración y Registro de Niveles

**User Story:** Como desarrollador, quiero un sistema declarativo para registrar niveles y sus subniveles, para facilitar la creación de contenido y el mantenimiento del juego.

#### Acceptance Criteria

1. THE Level_Manager SHALL cargar la configuración de niveles desde un recurso de datos (Resource personalizado o archivo JSON) que define la secuencia de pisos, rutas de escenas y subniveles asociados.
2. THE Level_Manager SHALL validar que cada entrada en la configuración de niveles contiene: identificador de piso, ruta a la Level_Scene, lista de subniveles con sus tipos y rutas, y tipo de jefe (minijefe o Major_Boss_Level).
3. WHEN se agrega un nuevo nivel a la configuración, THE Level_Manager SHALL incorporarlo en la secuencia de progresión sin requerir modificaciones en el código fuente del Level_Manager.
4. IF la configuración de niveles contiene una entrada inválida o una ruta de escena inexistente, THEN THE Level_Manager SHALL registrar un error descriptivo en el log indicando el piso y el campo problemático.
