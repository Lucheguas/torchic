# 🔥 Torchic

Torchic reinventa la fórmula de los plataformas clásicos al más puro estilo *Super Mario Bros.*, añadiendo un explosivo sistema de combate con armas. Ábrete paso a tiros entre hordas de enemigos, supera peligrosos obstáculos y prepárate para el desafío definitivo: derrotar al jefe final, un implacable pajarito que no se rendirá sin dar la pelea de su vida.

Un platformer 2D pixel art hecho en **Godot 4.7**, con GDScript.

---

## ✨ Características

- Plataformeo 2D clásico con *game feel* pulido (salto variable, coyote time, buffer de salto).
- Sistema de combate cuerpo a cuerpo con armas intercambiables.
- Enemigos con y sin armadura que exigen distintas tácticas (pisotón vs. golpe).
- Progresión por pisos con sublevels, checkpoints y transiciones.
- Un jefe final que sella la salida hasta ser derrotado.

---

## 🎮 Controles

| Acción | Tecla |
|---|---|
| Moverse a la izquierda | `A` / `←` |
| Moverse a la derecha | `D` / `→` |
| Saltar | `W` / `↑` / `Espacio` |
| Atacar | `K` |
| Recoger arma | `E` |
| Soltar arma | `G` |

---

## 🕹️ Mecánicas del personaje

El jugador es un `CharacterBody2D` controlado por `MovementController`. Su movimiento busca respuesta inmediata y control fino en el aire.

### Movimiento
- **Horizontal instantáneo**: sin aceleración ni fricción. Pulsar dirección aplica velocidad al instante y soltarla la corta en seco — decisión de *game feel* del GDD.
- **Velocidad efectiva** modulada por dos factores: un multiplicador de nivel (`base_speed`, 1.0–1.7) y un bonus de equipo (`speed_modifier`, 0.0–0.5).

### Salto
- **Salto de altura variable**: cuanto más se mantiene el botón, más alto sube (con un mínimo garantizado). Soltar antes recorta el impulso (*jump cut*).
- **Gravedad asimétrica**: la caída es más pesada que el ascenso, para un arco de salto satisfactorio.
- **Coyote time** (~100 ms): puedes saltar un instante después de dejar la plataforma.
- **Buffer de salto** (~120 ms): un salto pulsado justo antes de aterrizar se ejecuta al tocar el suelo.
- **Doble salto**: disponible como modificador desbloqueable.

### Pisotón (stomp)
- Caer sobre un enemigo desde arriba lo pisotea y rebota al jugador hacia arriba.
- Mantener el botón de salto durante el pisotón da un **rebote mejorado** (más altura).
- Una ventana de gracia tras el pisotón evita que un enemigo con armadura (que sobrevive) mate al jugador por contacto mientras rebota.

### Combate
- El jugador porta **una sola arma** a la vez (`MeleeAttack` + `MeleeWeapon`).
- El ataque activa brevemente una hitbox orientada según hacia dónde mira el personaje.
- El arma puede **recogerse (`E`)** de pedestales o del suelo, e **intercambiarse**: al recoger una nueva, la anterior queda disponible en el suelo. También puede **soltarse (`G`)**, quedando desarmado hasta recoger otra.
- El alcance del ataque supera el rango de muerte por contacto lateral, así que puedes golpear a un enemigo sin morir al tocarlo.

### Muerte
- El contacto con un enemigo por el **lado o por abajo** es letal (el contacto desde arriba es un pisotón, no daño).
- Las **kill zones** (pozos/abismos) delegan la muerte al `LevelManager`, que gestiona el respawn en checkpoint.

---

## 👾 Mecánicas de los enemigos

Los enemigos derivan de `BaseEnemy` (`CharacterBody2D`), que define salud, armadura y la matriz de daño.

### Salud y armadura
- Cada enemigo tiene `hp` y una bandera `has_armor`.
- **Matriz de daño** (`DamageType { STOMP, MELEE }`):

  | Estado | Pisotón (STOMP) | Golpe cuerpo a cuerpo (MELEE) |
  |---|---|---|
  | **Con armadura** | Absorbido (no recibe daño) | Rompe la armadura (no baja hp) |
  | **Sin armadura** | Muerte de un golpe | Resta `weapon.damage` a la `hp` |

  En resumen: un enemigo con armadura **debe** golpearse con arma para romperla antes de poder pisotearlo o rematarlo. Un enemigo sin armadura siempre muere de un solo pisotón, sin importar su `hp`.
- Al romperse la armadura se emite la señal `armor_broken`, que las subclases usan para cambiar su aspecto.

### Knockback
- Un golpe que el enemigo sobrevive (por ejemplo, al romperle la armadura) lo **empuja horizontalmente** por un instante, dando espacio para el siguiente ataque. El knockback domina sobre el comportamiento normal mientras dura.

### Detección de pisotón
- Los enemigos pisoteables tienen un `StompArea` (Area2D).
- El pisotón se detecta por **posición** (el jugador está por encima en el momento del solape), no por velocidad, porque la resolución de colisión puede anular la velocidad vertical antes de que dispare la señal.

### `EnemyBasic` (Tier 0.5 — tutorial)
- **Patrulla horizontal** entre dos límites alrededor de su punto de aparición.
- Invierte su dirección al llegar al límite o al chocar con una pared.
- Usa sprites dedicados por dirección; si arranca con armadura, muestra su set "armadura intacta" y cambia a "armadura rota" al perderla.

### Jefe final
- Vive en la sala de jefe del piso 3 (`floor_3_boss_room`).
- La salida del nivel permanece **sellada** hasta derrotarlo; al morir el jefe, se abre la puerta y se revela su visual.

---

## 🚀 Cómo ejecutar

1. Instala [Godot Engine 4.7](https://godotengine.org/) (renderer *GL Compatibility*).
2. Clona el repositorio.
3. Abre el proyecto (`project.godot`) desde el gestor de proyectos de Godot.
4. Pulsa **F5** para ejecutar. La escena inicial es el menú principal (`scenes/main_menu.tscn`).

---

## 🗂️ Estructura del proyecto

```
torchic/
├── scenes/                 # Escenas (.tscn): player, enemigos, niveles, menús
│   ├── levels/             # Pisos y sublevels
│   └── level_system/       # Instancias de triggers, checkpoints, etc.
├── scripts/                # Lógica en GDScript
│   ├── enemies/            # BaseEnemy y derivados
│   ├── weapons/            # MeleeWeapon (datos) y MeleeAttack (hitbox)
│   ├── level_system/       # LevelManager, checkpoints, transiciones, data
│   ├── triggers/           # PlayerTrigger y derivados
│   ├── movement_controller.gd
│   └── modifier_stack.gd
├── resources/              # Recursos serializados (.tres)
├── assets/                 # Pixel art (backgrounds, sprites)
└── test/                   # Tests GdUnit4
```

---

## 🧪 Testing

- **Framework**: [GdUnit4](https://github.com/MikeSchulze/gdUnit4) (config en `.gdunit4.cfg`).
- **Ubicación**: `test/`.
- Cubre propiedades matemáticas puras (clamping, aritmética de daño), casos edge y un smoke test que valida que `floor_1.tscn` carga sin errores.

---

## 🛠️ Stack técnico

- **Motor**: Godot Engine 4.7 (GL Compatibility)
- **Lenguaje**: GDScript
- **Arquitectura**: POO con herencia acotada (`BaseEnemy`, `PlayerTrigger`) y composición (`MovementController` compone un `ModifierStack`). Ver `.kiro/steering/project-architecture.md` para las convenciones completas.
