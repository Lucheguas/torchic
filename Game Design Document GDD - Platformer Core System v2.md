# **Game Design Document (GDD): Platformer Core System & Mechanic Architecture**

## **1\. Lógica del Juego y Reglas Fundamentales**

### **1.1. Mecánicas de Daño y Combate Base**

* **Pisotón Estándar:** Pisar a un enemigo sin armadura elimina al enemigo instantáneamente y otorga un impulso de **rebote automático** al personaje, facilitando el encadenamiento de saltos en el aire y la exploración vertical.  
* **Enemigos con Armadura M:** La *Armadura M* es una propiedad exclusiva de ciertos enemigos. Cualquier contacto con un enemigo dotado de Armadura M inflige daño al jugador (incluso si intenta pisarlo). Obliga al jugador a usar armas cuerpo a cuerpo o artefactos.  
* **Combate Melee:** El ataque cuerpo a cuerpo ignora la Armadura M y destruye al enemigo según el cálculo de daño e HP.

### **1.2. Caídas al Vacío, Checkpoints y Muerte**

* **Checkpoints en Niveles Principales:** Cada mapa principal se divide dinámicamente en tercios. Se fijará un checkpoint automático al cumplir el **33%** y el **66%** de la distancia del mapa. Si el personaje cae al vacío o muere en el tramo principal, reaparecerá en el checkpoint activo más cercano.  
* **Checkpoints en Subniveles:**  
  * Se coloca un checkpoint de entrada justo antes de acceder a la transición del subnivel.  
  * Se coloca un checkpoint de salida inmediatamente después de completar el subnivel.  
  * **Muerte dentro del Subnivel:** Al caer al vacío o morir por trampas/artefactos dentro de un subnivel (dado que son secciones cortas e intensas), el jugador reaparece al inicio del subnivel correspondiente, sin perder el progreso global del piso.

### **1.3. Estructura de Niveles y Jefes**

* El juego consta de **15 Niveles Totales** de progresión continua.  
* **Jefes Intermedios:** Cada piso contiene una prueba o minijefe al final del mapa.  
* **Jefes Mayores:** Cada 5 pisos (Piso 5, Piso 10 y Piso 15\) se presenta un Jefe Mayor con mecánicas únicas de combate. \*(Sección reservada en blanco para definición posterior de entidades y patrones)\*.

## ---

**2\. Sistemas Económicos y Progresión**

### **2.1. Separación de Economías**

* **Puntos de Experiencia (EXP):** Se obtienen exclusivamente derrotando enemigos. Acumular puntos aumenta de forma automática el Nivel del Personaje, incrementando sus estadísticas base (HP, Daño, Velocidad).  
* **Tokens (Moneda de Exploración):** Monedas recolectables encontradas en el mapa, en **Bloques de Tokens** (estilo Mario, golpeables desde abajo) o cofres explorables. Los tokens se gastan en las tiendas de "Entre-Nivel" con el Fantasmita para adquirir equipamiento (Armas, Armaduras, Botas).

### **2.2. Balance de Enemigos (Tiers 1 al 15\)**

Ajuste de velocidad: Los enemigos mantienen Velocidad \= 1 desde el Nivel 1 hasta el Nivel 10\. A partir del Nivel 11 hasta el Nivel 15, la velocidad escala a 2\. La experiencia otorgada por cada enemigo escala progresivamente para requerir una densidad controlada de derrotas por piso.

| Tier Enemigo | HP | Daño | Velocidad | Puntos Otorgados | Arquetipo de Comportamiento   |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Tier 0.5** | 1 | 1 | 1 | 10 pts | Patrullero Terrestre (Línea recta) |
| **Tier 1** | 2 | 1 | 1 | 15 pts | Patrullero Terrestre (Línea recta) |
| **Tier 2** | 4 | 2 | 1 | 25 pts | Patrullero / Salto Básico |
| **Tier 3** | 6 | 3 | 1 | 40 pts | Perseguidor Lento / Blindado Spiny |
| **Tier 4** | 8 | 4 | 1 | 60 pts | Perseguidor / Blindado Spiny |
| **Tier 5** | 10 | 5 | 1 | 85 pts | Enemigo Volador (Trayectoria Senoidal) |
| **Tier 6** | 12 | 6 | 1 | 115 pts | Perseguidor Aéreo |
| **Tier 7** | 14 | 7 | 1 | 150 pts | Blindado Pesado (Spiny \+ Carga) |
| **Tier 8** | 16 | 8 | 1 | 190 pts | Perseguidor Agresivo Terrestre |
| **Tier 9** | 18 | 9 | 1 | 240 pts | Volador Blindado (Dispara proyectil) |
| **Tier 10** | 20 | 10 | 1 | 300 pts | Mini-Jefe de Elite / Spiny Avanzado |
| **Tier 11** | 24 | 12 | 2 | 370 pts | Rápido Perseguidor (Velocidad 2\) |
| **Tier 12** | 28 | 14 | 2 | 450 pts | Volador Rápido de Emboscada |
| **Tier 13** | 32 | 16 | 2 | 540 pts | Blindado Pesado Rápido |
| **Tier 14** | 36 | 18 | 2 | 640 pts | Predador Aéreo Rápido |
| **Tier 15** | 40 | 20 | 2 | 750 pts | Guardián Final / Elite de Piso 15 |

### **2.3. Tabla de Progresión del Jugador (Niveles 1 al 15\)**

Muestra los puntos acumulados necesarios para subir de nivel y la cantidad estimada de derrotas del tier equivalente por piso para alcanzarlo de forma orgánica.

| Nivel Jugador | Puntos Requeridos (Total) | HP Base | Daño Base | Velocidad Base | Derrotas Estimadas para Level Up   |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Nivel 1** | 0 pts | 3 | 1 | 1.0 | \- |
| **Nivel 2** | 30 pts | 5 | 2 | 1.0 | 2 enemigos Tier 1 |
| **Nivel 3** | 80 pts | 7 | 3 | 1.1 | 2 enemigos Tier 2 |
| **Nivel 4** | 160 pts | 9 | 4 | 1.1 | 2 enemigos Tier 3 |
| **Nivel 5** | 280 pts | 11 | 5 | 1.2 | 2 enemigos Tier 4 |
| **Nivel 6** | 450 pts | 13 | 6 | 1.2 | 2 enemigos Tier 5 |
| **Nivel 7** | 680 pts | 15 | 7 | 1.3 | 2 enemigos Tier 6 |
| **Nivel 8** | 980 pts | 17 | 8 | 1.3 | 2 enemigos Tier 7 |
| **Nivel 9** | 1,360 pts | 19 | 9 | 1.4 | 2 enemigos Tier 8 |
| **Nivel 10** | 1,840 pts | 21 | 10 | 1.4 | 2 enemigos Tier 9 |
| **Nivel 11** | 2,440 pts | 23 | 11 | 1.5 | 2 enemigos Tier 10 |
| **Nivel 12** | 3,180 pts | 25 | 12 | 1.5 | 2 enemigos Tier 11 |
| **Nivel 13** | 4,080 pts | 27 | 13 | 1.6 | 2 enemigos Tier 12 |
| **Nivel 14** | 5,160 pts | 29 | 14 | 1.6 | 2 enemigos Tier 13 |
| **Nivel 15** | 6,440 pts | 31 | 15 | 1.7 | 2 enemigos Tier 14 |

## ---

**3\. Sistema de Equipamiento en Tiendas**

Comprables en la tienda de entre-nivel mediante Tokens acumulados.

| Categoría | Nombre del Artefacto | Efecto / Bonificación | Costo (Tokens)   |
| :---- | :---- | :---- | :---- |
| **Armas Melee** | Daga de Madera | \+1 al Daño Melee | 20 Tokens |
|  | Espada de Acero | \+3 al Daño Melee | 50 Tokens |
|  | Maza Pesada | \+5 al Daño Melee, rompe escudos lentos | 90 Tokens |
|  | Hoja Rúnica de IA | \+8 al Daño Melee, incrementa alcance de ataque | 140 Tokens |
| **Armaduras del Jugador** | Chaleco de Cuero | \+2 HP Máximo, absorbe 5% de daño recibido | 25 Tokens |
|  | Malla de Hierro | \+5 HP Máximo, absorbe 10% de daño recibido | 55 Tokens |
|  | Peto de Placas | \+9 HP Máximo, absorbe 15% de daño recibido | 95 Tokens |
|  | Coraza Energética | \+14 HP Máximo, inmunidad a proyectiles menores | 150 Tokens |
| **Botas** | Botas de Tela | \+0.1 Velocidad de Movimiento | 15 Tokens |
|  | Botas de Cuero Reforzado | \+0.2 Velocidad de Movimiento, \+5% Altura de Salto | 40 Tokens |
|  | Botas Furia de Viento | \+0.35 Velocidad de Movimiento, permite Doble Salto corto | 80 Tokens |
|  | Botas Gravitacionales | \+0.5 Velocidad de Movimiento, rebote de pisotón aumentado x2 | 130 Tokens |

## ---

**4\. Integración del Fantasmita y Artefactos Aliados**

### **4.1. Comportamiento Estándar**

* El fantasmita acompaña flotando al jugador. Por defecto **no interactúa con los enemigos ni con las colisiones del mapa**.  
* **Sincronización de Animación:** Cada vez que el jugador realiza un ataque melee, el fantasmita activa simultáneamente su animación de ataque (sprite de ataque), aportando feedback visual continuo sin alterar el balance de combate base.

### **4.2. Artefactos de Aliado (Modificadores Activos del Fantasmita)**

Si el jugador equipa un Artefacto de Aliado específico en la tienda, el fantasmita adquiere habilidades activas en combate:

| Tipo de Artefacto | Versión Estándar | Versión Legendaria   |
| :---- | :---- | :---- |
| **1\. Artefacto de Cura (Orbe Espiritual)** | Tras 3 segundos de sufrir daño, el fantasmita cura 1 HP al personaje cada 2 segundos. Se interrumpe si el personaje vuelve a recibir daño. | Tras 3 segundos de sufrir daño, la regeneración se acelera curando 1 HP cada 1 segundo. |
| **2\. Artefacto de Daño (Núcleo Ígneo)** | Otorga \+3 de daño base al personaje. El fantasmita dispara automáticamente su ataque de fuego a distancia cada 3 segundos al enemigo más cercano (daña al enemigo directamente sin interactuar con las plataformas ni paredes del entorno). | Incrementa la frecuencia del disparo de fuego del fantasmita, reduciendo el cooldown a un ataque cada 1.5 segundos. |
| **3\. Artefacto de Escudo (Aura Protectora)** | Genera una barrera que absorbe totalmente el próximo impacto de daño. Una vez roto, entra en cooldown durante 15 segundos antes de regenerarse. | Reduce el tiempo de recarga del escudo protector a solo 7 segundos tras ser absorbido un impacto. |

## ---

**5\. Subniveles**

Para evitar sobrecargar los mapas principales y diversificar el gameplay, los subniveles son secciones cortas e intensas que se cargan como escenas independientes y se enlazan al flujo lineal del piso mediante transiciones suaves.

### **5.1. Cámara**

* El juego usa una **cámara 2D estándar** (`Camera2D`) que es hija del `Player` y lo sigue mientras se desplaza. Mantiene siempre zoom `Vector2(1, 1)`, offset `Vector2(0, 0)` y rotación `0.0`, sin cambios de perspectiva. Tanto en los pisos principales como en los subniveles la cámara conserva esta misma perspectiva lateral 2D.

### **5.2. Transición Visual Cuidada**

* Al entrar a un subnivel (puerta, tubería o portal de datos), se ejecuta una breve animación de entrada (por ejemplo, un efecto de congelamiento estilo glitch en Pixel Art) que dura 1.5 segundos. Esto evita cualquier salto brusco de encuadre.

### **5.3. Ideas de Subniveles**

* **Subnivel Tipo Persecución (Huída estilo Crash Bandicoot):**  
  * *Mecánica:* Una esfera de piedra masiva o un muro de corrupción digital persigue al jugador desde atrás.  
  * *Acciones:* El jugador debe esquivar vacíos, saltar sobre vallas o trampas de fuego y recolectar tokens que aparecen en el camino.  
* **Subnivel de Avance/Infiltración:**  
  * *Mecánica:* El jugador avanza por un pasillo evitando ser detectado.  
  * *Acciones:* Se requiere esquivar obstáculos o interactuar de forma precisa en la ruta.  
* **Subnivel de Apuntado y Precisión:**  
  * *Mecánica:* El personaje permanece en un riel o plataforma fija y usa el cursor del mouse para apuntar.  
  * *Acciones:* Destruir nodos de datos o proyectiles enemigos en el aire antes de que colisionen con la plataforma móvil.  
* **Subnivel de Puzzles Ambientales:**  
  * *Mecánica:* Sala cerrada de circuitos con obstáculos de entorno.  
  * *Acciones:* Mover bloques, presionar interruptores en un tiempo límite para abrir la puerta de salida y regresar al recorrido lateral 2D.

> ---

> 6\. Arquetipos de Enemigos por Tier

* ## **Tiers Bajos (Tier 0.5 \- Tier 2): Caminan en línea recta sobre plataformas fijas. Cambian de dirección al colisionar con bordes o paredes. Fácilmente eliminables con pisotón o ataque melee.**

  * **Tiers de Velocidad Alta y Voladores (Tier 3 \- Tier 6 / Tiers 11-14):** Patrones de persecución activa en cuanto el jugador entra en su rango de detección. Los voladores realizan trayectorias onduladas o de embestida recta.  
  * **Enemigos Blindados (Tipo Spiny):** Poseen la *Armadura M* integrada en su diseño (espinas, caparazones electrificados). Inmunes y dañinos ante pisotones. Obligan al jugador a detenerse y usar armas melee o habilidades del fantasmita.

> ---

> 7\. Especificaciones Técnicas y de UI (Estilo Pokémon Esmeralda)

* ## **HUD Minimalista: Cuadro de vida con corazones o segmentos simples en la esquina superior izquierda. Contador de Tokens con icono pixelado en la esquina superior derecha. Marco de interfaz en tonos oscuros redondeados con fuente limpia estilo pixel.**

  * **Estilo de Arte:** Sprites con contornos negros marcados, sombreado plano de 2 a 3 tonos por color y paletas de colores vibrantes pero saturadas.