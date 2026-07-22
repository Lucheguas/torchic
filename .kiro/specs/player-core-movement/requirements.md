# Requirements Document

## Introduction

Este documento define los requerimientos del sistema de movimiento principal del jugador para el platformer 2D "Torchic", desarrollado en Godot 4.x con GDScript. El sistema abarca movimiento horizontal instantáneo (sin aceleración/desaceleración), salto variable, gravedad, mecánica de pisotón con rebote, coyote time, input buffering, y un sistema de modificadores de velocidad que soportará equipamiento. El estilo visual es pixel art (estética Pokémon Esmeralda) en un side-scroller 2D.

## Glossary

- **Player_Character**: Nodo CharacterBody2D que representa al personaje controlado por el jugador en el mundo 2D.
- **Movement_Controller**: Script GDScript adjunto al Player_Character que gestiona toda la lógica de movimiento, salto y gravedad.
- **Base_Speed**: Valor numérico flotante que representa la velocidad base del personaje según su nivel (1.0 en Nivel 1, escala hasta 1.7 en Nivel 15).
- **Speed_Modifier**: Valor numérico flotante agregado por equipamiento (botas) que se suma al Base_Speed para obtener la velocidad efectiva.
- **Effective_Speed**: Resultado de Base_Speed + Speed_Modifier, utilizado para calcular la velocidad de movimiento horizontal.
- **Coyote_Time**: Ventana de gracia en milisegundos tras abandonar el borde de una plataforma donde el salto aún es permitido.
- **Input_Buffer**: Ventana de tiempo en milisegundos que almacena la última pulsación de salto para ejecutarla cuando el personaje aterriza.
- **Stomp_Bounce**: Impulso vertical automático aplicado al Player_Character tras eliminar un enemigo mediante pisotón.
- **Variable_Jump**: Mecánica que permite controlar la altura del salto según la duración de la pulsación del botón de salto.
- **Ground_State**: Estado del Player_Character cuando está en contacto con el suelo (is_on_floor() retorna true).
- **Air_State**: Estado del Player_Character cuando no está en contacto con el suelo.
- **Landing_Event**: Evento que se emite cuando el Player_Character transiciona de Air_State a Ground_State.

## Requirements

### Requirement 1: Movimiento Horizontal Instantáneo

**User Story:** Como jugador, quiero mover al personaje a la izquierda y a la derecha con respuesta instantánea, para que el control se sienta directo y preciso como un platformer clásico.

#### Acceptance Criteria

1. WHEN el jugador presiona la dirección izquierda o derecha, THE Movement_Controller SHALL aplicar la Effective_Speed completa al Player_Character de forma instantánea en la dirección indicada sin aceleración progresiva.
2. WHEN el jugador suelta la dirección de movimiento, THE Movement_Controller SHALL detener la velocidad horizontal del Player_Character inmediatamente sin desaceleración (velocidad horizontal igual a cero).
3. THE Movement_Controller SHALL calcular la Effective_Speed como la suma de Base_Speed y Speed_Modifier.
4. WHILE el Player_Character se encuentra en Air_State, THE Movement_Controller SHALL aplicar el mismo modelo de movimiento instantáneo que en Ground_State.
5. WHEN el jugador cambia de dirección horizontal, THE Movement_Controller SHALL invertir la velocidad horizontal del Player_Character de forma instantánea sin transición intermedia.

### Requirement 2: Salto con Altura Variable

**User Story:** Como jugador, quiero controlar la altura del salto según el tiempo que mantenga presionado el botón, para tener control preciso sobre la navegación vertical.

#### Acceptance Criteria

1. WHEN el jugador presiona el botón de salto y el Player_Character se encuentra en Ground_State, THE Movement_Controller SHALL aplicar un impulso vertical inicial al Player_Character.
2. WHILE el jugador mantiene presionado el botón de salto y el Player_Character asciende, THE Movement_Controller SHALL mantener la fuerza de salto hasta alcanzar la altura máxima de salto o hasta que el jugador suelte el botón.
3. WHEN el jugador suelta el botón de salto antes de alcanzar la altura máxima, THE Movement_Controller SHALL reducir la velocidad vertical ascendente multiplicándola por un factor de corte para acortar el salto.
4. THE Movement_Controller SHALL definir una altura mínima de salto que se aplica incluso en pulsaciones instantáneas del botón.

### Requirement 3: Gravedad y Caída

**User Story:** Como jugador, quiero que la gravedad afecte consistentemente al personaje cuando está en el aire, para que el movimiento se sienta natural y predecible.

#### Acceptance Criteria

1. WHILE el Player_Character se encuentra en Air_State, THE Movement_Controller SHALL aplicar gravedad incrementando la velocidad vertical descendente cada frame de física.
2. THE Movement_Controller SHALL limitar la velocidad de caída a un valor máximo definido (velocidad terminal) para evitar caídas excesivamente rápidas.
3. WHILE el Player_Character desciende, THE Movement_Controller SHALL aplicar un multiplicador de gravedad mayor que durante el ascenso para crear una sensación de caída más pesada y responsiva.

### Requirement 4: Mecánica de Pisotón con Rebote

**User Story:** Como jugador, quiero que al pisar un enemigo sin armadura el personaje reciba un impulso de rebote automático, para facilitar el encadenamiento de saltos y la exploración vertical.

#### Acceptance Criteria

1. WHEN el Player_Character colisiona con un enemigo sin Armadura M desde arriba mientras se encuentra en Air_State descendente, THE Movement_Controller SHALL aplicar un Stomp_Bounce vertical ascendente al Player_Character.
2. THE Movement_Controller SHALL definir una magnitud base para el Stomp_Bounce que permita alcanzar plataformas inmediatamente superiores al enemigo eliminado.
3. WHILE el jugador mantiene presionado el botón de salto durante un Stomp_Bounce, THE Movement_Controller SHALL aplicar un impulso de rebote incrementado para alcanzar mayor altura.
4. THE Movement_Controller SHALL exponer un multiplicador de Stomp_Bounce configurable para que el sistema de equipamiento pueda modificar la fuerza del rebote (por ejemplo, Botas Gravitacionales aplican multiplicador x2).

### Requirement 5: Coyote Time

**User Story:** Como jugador, quiero tener una ventana de gracia para saltar tras abandonar el borde de una plataforma, para que el juego perdone errores de timing y se sienta justo.

#### Acceptance Criteria

1. WHEN el Player_Character transiciona de Ground_State a Air_State sin ejecutar un salto, THE Movement_Controller SHALL iniciar un temporizador de Coyote_Time.
2. WHILE el temporizador de Coyote_Time esté activo, THE Movement_Controller SHALL permitir al jugador ejecutar un salto como si estuviera en Ground_State.
3. WHEN el temporizador de Coyote_Time expira, THE Movement_Controller SHALL deshabilitar la posibilidad de salto hasta que el Player_Character retorne a Ground_State o se active otra condición de salto válida.
4. WHEN el jugador ejecuta un salto durante el Coyote_Time, THE Movement_Controller SHALL consumir el Coyote_Time inmediatamente e impedir un segundo salto durante la misma ventana.

### Requirement 6: Input Buffering para Salto

**User Story:** Como jugador, quiero que el sistema recuerde mi pulsación de salto si la ejecuto ligeramente antes de aterrizar, para que las cadenas de saltos sean fluidas y no se pierdan inputs.

#### Acceptance Criteria

1. WHEN el jugador presiona el botón de salto mientras el Player_Character se encuentra en Air_State y no puede saltar, THE Movement_Controller SHALL almacenar la solicitud de salto en el Input_Buffer durante una ventana de tiempo configurable.
2. WHEN el Player_Character aterriza en Ground_State y existe una solicitud de salto en el Input_Buffer que no ha expirado, THE Movement_Controller SHALL ejecutar el salto inmediatamente al aterrizar.
3. WHEN la ventana de tiempo del Input_Buffer expira sin que el Player_Character haya aterrizado, THE Movement_Controller SHALL descartar la solicitud de salto almacenada.

### Requirement 7: Evento de Aterrizaje

**User Story:** Como jugador, quiero que el aterrizaje tenga retroalimentación visual, para que la interacción con el suelo se sienta sólida y satisfactoria.

#### Acceptance Criteria

1. WHEN el Player_Character transiciona de Air_State a Ground_State, THE Movement_Controller SHALL emitir un Landing_Event.
2. WHEN se emite un Landing_Event, THE Player_Character SHALL activar la animación de aterrizaje correspondiente.
3. THE Movement_Controller SHALL emitir el Landing_Event únicamente cuando la velocidad vertical previa al aterrizaje excede un umbral mínimo, para evitar activar la animación en caídas insignificantes.

### Requirement 8: Sistema de Modificadores de Velocidad

**User Story:** Como jugador, quiero que el equipamiento (botas) modifique mi velocidad y características de movimiento, para sentir progresión tangible al adquirir mejor equipo.

#### Acceptance Criteria

1. THE Movement_Controller SHALL mantener un Speed_Modifier que se suma al Base_Speed para calcular la Effective_Speed.
2. WHEN se equipa un objeto que modifica la velocidad, THE Movement_Controller SHALL actualizar el Speed_Modifier con el valor correspondiente al objeto equipado.
3. WHEN se desequipa un objeto que modifica la velocidad, THE Movement_Controller SHALL revertir el Speed_Modifier al valor previo o a cero si no hay otro objeto equipado.
4. THE Movement_Controller SHALL aceptar modificadores adicionales de salto (porcentaje de altura de salto adicional) proporcionados por el sistema de equipamiento.
5. WHERE el equipamiento habilita Doble Salto, THE Movement_Controller SHALL permitir un salto adicional en Air_State una vez por ciclo de vuelo (hasta que el Player_Character retorne a Ground_State).
6. THE Movement_Controller SHALL soportar los siguientes rangos de Speed_Modifier: mínimo +0.0, máximo +0.5, correspondientes a las botas definidas en el sistema de equipamiento.

### Requirement 9: Escalado de Velocidad Base por Nivel

**User Story:** Como jugador, quiero que mi personaje sea más rápido conforme sube de nivel, para percibir una sensación de progresión natural.

#### Acceptance Criteria

1. THE Movement_Controller SHALL obtener el valor de Base_Speed a partir del nivel actual del Player_Character según la tabla de progresión (1.0 en Nivel 1 hasta 1.7 en Nivel 15).
2. WHEN el Player_Character sube de nivel, THE Movement_Controller SHALL actualizar el Base_Speed al valor correspondiente al nuevo nivel.
3. THE Movement_Controller SHALL interpolar linealmente el Base_Speed entre los valores definidos en la tabla de progresión para los niveles intermedios.
