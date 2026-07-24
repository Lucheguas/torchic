# 🎮 Torchic - Especificación Técnica de Diseño: Mapa 1 (Nivel Tutorial)

> **Documento de Requerimientos y Diseño para Implementación**
> **Destinatario / Asistente:** Kiro
> **Motor:** Godot 4.7 (GL Compatibility)
> **Escena de Destino:** `res://scenes/levels/floor_1.tscn`
> **Escala del Personaje:** Sprite escalado a 0.18, colisión CapsuleShape2D (radio=14, alto=48)

---

## 1. Contexto del Proyecto y Objetivos

Este documento define la estructura y distribución del **Mapa 1 (Nivel Tutorial)** para el proyecto **Torchic**. Inspirado en el diseño pedagógico del Nivel 1-1 de *Super Mario Bros.*, este nivel introduce de forma orgánica las mecánicas principales del juego sin depender de cuadros de texto intrusivos.

### Mecánicas a Validar en el Tutorial:
1. **Movimiento Básico Horizontal:** Teclas `A`/`D` o Flechas.
2. **Salto Básico y Salto Variable:** Duración de pulsación para controlar la altura (`jump_velocity` y `jump_cut_multiplier`).
3. **Pisotón / Stomp Bounce:** Colisión superior sobre enemigos para rebotar y causar daño.
4. **Coyote Time y Buffer de Salto:** Navegación en bordes y precisión de caídas.
5. **Transición de Subnivel / Punto Final:** Interacción con `TransitionTrigger` para cambiar de zona o completar el piso.

---

## 2. Desglose Estructural por Zonas

### Zona 1: La Explanada (Inicio y Movimiento)
* **Propósito:** Espacio seguro y despejado para familiarizarse con la velocidad horizontal (`base_pixel_speed = 300 px/s`).
* **Elementos:**
  * Punto de aparición del Jugador (`Player`).
  * Terreno totalmente plano de al menos 800px de longitud.
  * Sin enemigos ni amenazas.

### Zona 2: El Primer Obstáculo (Pared Corta)
* **Propósito:** Enseñar al jugador la necesidad de saltar para superar obstáculos del entorno.
* **Elementos:**
  * Estructura vertical pequeña (aprox. 64–96px de alto).
  * Exige un salto simple para sobrepasarla.
  * Caída hacia un suelo seguro tras la pared.

### Zona 3: Primer Encuentro con Enemigo (Mecánica de Pisotón)
* **Propósito:** Enseñar el combate mediante pisotón (*Stomp Bounce*).
* **Elementos:**
  * Terreno plano con 1 enemigo básico (Tier 0.5) patrullando de izquierda a derecha.
  * Espacio vertical libre encima del enemigo para facilitar la alineación del salto.

### Zona 4: Desafío de Alturas (Plataformas y Salto Variable)
* **Propósito:** Enseñar la diferencia entre saltos cortos y saltos altos mantenidos, además de explorar distintas elevaciones.
* **Elementos:**
  * Conjunto de bloques/plataformas elevadas en el aire (estilo bloques de Mario).
  * 1 enemigo patrullando encima de las plataformas o por debajo.
  * Espacio para probar el doble salto si estuviera equipado.

### Zona 5: El Abismo Corto (Riesgo y Precisión)
* **Propósito:** Introducir la consecuencia de caer a una fosa y poner a prueba el *Coyote Time* (100ms) y el *Input Buffer* (120ms).
* **Elementos:**
  * Una fosa corta entre dos plataformas (ancho recomendado: 120–160px).
  * Fosa con trigger de reaparición o muerte que reinicie en el último checkpoint.

### Zona 6: Transición / Portal de Salida
* **Propósito:** Enseñar la mecánica de cambio de escena o entrada a subniveles.
* **Elementos:**
  * `CheckpointMarker` antes de la transición.
  * Estructura de salida (`TransitionTrigger` tipo `SUBLEVEL` o `NEXT_FLOOR`).
  * Marcador visual de final de nivel.

---

## 3. Diagramas Visuales del Layout

### Esquema de Flujo General:
```text
 (INICIO)
    |
    v
[Zona 1: Explanada]  -->  [Zona 2: Pared Corta]  -->  [Zona 3: Enemigo Tiers 0.5]
  (Mover Izq / Der)          (Prueba de Salto)           (Aprender a Pisar / Stomp)
                                                      
                                                                 |
                                                                 v
                                                     [Zona 4: Plataformas Elevadas]
                                                        (Salto Variable + Enemigo)
                                                                 |
                                                                 v
[META / TRANSICIÓN]  <--  [Zona 6: Portal / Tubería]  <--  [Zona 5: Abismo Corto]
  (Siguiente Piso)          (Acceso a Subnivel)            (Caída / Coyote Time)
```

### Layout de Caracteres (Nivel 2D):
```text
LEYENDA:
  [ P ]  : Jugador (Spawn / Posición Inicial)
  [ E ]  : Enemigo de prueba (Tier 0.5 / Patrulla)
  [ C ]  : Checkpoint Marker
  [ S ]  : TransitionTrigger (Salida / Portal / Tubería)
  [===]  : Suelo / Plataforma Principal (StaticBody2D / TileMap)
  [ | ]  : Paredes / Obstáculos
  [ M ]  : Bloques / Plataformas Elevadas

                                                 [M][M][M]
                                       [E]       _________
                        ___           ____       |       |       [C]
      [P]  _________    | |  [E]     |    |      |       |      [S]
    _______|       |____| |__________|    |______|       |______|___|
    |                                                               |
    |                      (Abismo)                                 |
____|                               ________________________________|
```

---

## 4. Estructura de Nodos Implementada (`floor_1.tscn`)

```text
Floor1 (Node2D)
├── Environment (Node2D)
│   ├── Ground_Main (StaticBody2D) [pos: (1050, 600), size: 2100x32]
│   ├── Wall_Zona2 (StaticBody2D) [pos: (900, 560), size: 32x80]
│   ├── Platform1 (StaticBody2D) [pos: (1600, 510), size: 96x16]
│   ├── Platform2 (StaticBody2D) [pos: (1750, 470), size: 96x16]
│   ├── Platform3 (StaticBody2D) [pos: (1900, 510), size: 96x16]
│   └── Ground_AfterPit (StaticBody2D) [pos: (2450, 600), size: 400x32]
├── Spawners (Node2D)
│   ├── PlayerSpawnPoint (Marker2D) [pos: (100, 570)]
│   ├── Checkpoint1 (Instance of checkpoint_marker.tscn) [pos: (1350, 580)]
│   ├── Checkpoint2 (Instance of checkpoint_marker.tscn) [pos: (2050, 580)]
│   ├── SublevelEntry (Instance of transition_trigger.tscn) [pos: (1950, 560), SUBLEVEL]
│   └── LevelEnd (Instance of transition_trigger.tscn) [pos: (2600, 560), NEXT_FLOOR]
├── Enemies (Node2D)
│   ├── Enemy_Tutorial_1 (Instance of enemy_basic.tscn) [pos: (1200, 584)]
│   └── Enemy_Tutorial_2 (Instance of enemy_basic.tscn) [pos: (1750, 454)]
├── KillZone (Area2D + kill_zone.gd) [pos: (2175, 700)]
└── Player (Instance of player.tscn) [pos: (100, 570)]
    └── Camera2D
```

### Distribución por Zonas:
- **Zona 1 (Explanada):** x=0 a x=800 — terreno plano, spawn del jugador
- **Zona 2 (Pared):** x=884 a x=916 — pared de 80px de alto
- **Zona 3 (Enemigo):** x=950 a x=1450 — Enemy_Tutorial_1 patrullando
- **Zona 4 (Plataformas):** x=1450 a x=2050 — 3 plataformas elevadas + Enemy_Tutorial_2
- **Zona 5 (Abismo):** x=2100 a x=2250 — fosa de 150px con KillZone
- **Zona 6 (Transición):** x=2250 a x=2650 — Checkpoint2 + LevelEnd

---

## 5. Instrucciones para Kiro (Implementación) — COMPLETADO

1. **Escala del Personaje:** Sprite escalado a 0.18x, colisión ajustada a CapsuleShape2D(radio=14, alto=48) para ~28x48px efectivos.
2. **Construcción Geométrica:** StaticBody2D con CollisionShape2D + ColorRect como visual placeholder para cada zona.
3. **Colocación de Entidades:**
   * Player instanciado en Zona 1 (x=100, y=570) con `Camera2D` hija estándar que sigue al jugador (zoom `Vector2(1, 1)`, offset `Vector2(0, 0)`, rotación `0.0`, sin cambios de perspectiva).
   * TransitionTrigger `SUBLEVEL` en Zona 4 (entrada a subnivel).
   * TransitionTrigger `NEXT_FLOOR` en Zona 6 (final del piso).
   * CheckpointMarkers en Zonas 3 y 5.
4. **Enemigos:** `enemy_basic.tscn` con patrulla horizontal y detección de stomp via Area2D.
5. **Kill Zone:** Area2D bajo el abismo que respawnea al jugador en el último checkpoint activo.
6. **Validación de Métricas:**
   * Pared Zona 2: 80px de alto — superable con salto básico (jump_velocity=-450, alcanza ~103px). ✓
   * Abismo Zona 5: 150px de ancho — superable a 300px/s en ~0.5s de salto. ✓
   * Plataforma alta (y=470): requiere salto mantenido completo (pico a ~y=467 desde suelo). ✓
