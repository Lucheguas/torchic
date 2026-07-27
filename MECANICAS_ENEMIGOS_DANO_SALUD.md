# Mecánicas de daño, salud y armadura de enemigos — Torchic

Referencia técnica de cómo los enemigos reciben daño, mueren y usan armadura.
Cubre la clase base, el enemigo básico y el lado del arma del jugador que
dispara el daño. Todo es GDScript sobre Godot 4.7.

## Archivos involucrados

| Archivo | Rol en el sistema de daño/salud |
|---|---|
| `scripts/enemies/base_enemy.gd` | Clase base `BaseEnemy`: HP, armadura, matriz de daño, knockback, muerte. |
| `scripts/enemy_basic.gd` | `EnemyBasic`: detección de stomp, contacto letal, tinte de armadura. |
| `scripts/weapons/melee_attack.gd` | `MeleeAttack`: hitbox del jugador que aplica daño MELEE y knockback. |
| `scripts/weapons/melee_weapon.gd` | `MeleeWeapon`: recurso de datos, aporta `damage`. |
| `scenes/enemy_basic.tscn` | Instancia con los valores por defecto (`hp`, `has_armor`, colores). |

---

## 1. Salud (HP)

Definida en `BaseEnemy`:

```gdscript
@export var hp: int = 1
@export var has_armor: bool = false
```

- `hp` es un entero exportado; por defecto `1`. En `enemy_basic.tscn` no se
  sobreescribe, así que el enemigo básico muere de un solo golpe efectivo.
- No hay HP máximo ni regeneración: el HP solo baja. La muerte se resuelve por
  `queue_free()` cuando `hp <= 0`.
- El HP solo se reduce cuando el enemigo **no** tiene armadura (ver matriz de
  daño abajo).

---

## 2. Tipos de daño

`BaseEnemy` define un enum con las dos vías por las que un enemigo recibe daño:

```gdscript
enum DamageType { STOMP, MELEE }
```

- **STOMP**: el jugador cae encima del enemigo (pisotón).
- **MELEE**: el jugador golpea con el arma cuerpo a cuerpo.

La distinción importa solo por la armadura: STOMP y MELEE hacen el mismo daño
numérico a un enemigo sin armadura, pero la armadura reacciona distinto a cada
uno.

---

## 3. Matriz de daño y armadura

Toda la lógica vive en `BaseEnemy.take_damage`:

```gdscript
func take_damage(amount: int, type: DamageType) -> void:
	if has_armor:
		if type == DamageType.MELEE:
			_break_armor()
		return

	hp -= amount
	if hp <= 0:
		queue_free()
```

Tabla resumen:

| Estado del enemigo | Daño STOMP | Daño MELEE |
|---|---|---|
| **Con armadura** (`has_armor = true`) | Absorbido. No pierde HP. La armadura sigue puesta. | Rompe la armadura (`_break_armor()`), no pierde HP. Queda vulnerable. |
| **Sin armadura** (`has_armor = false`) | `hp -= amount`; muere si `hp <= 0`. | `hp -= amount`; muere si `hp <= 0`. |

Reglas clave:

1. **La armadura absorbe el STOMP por completo** y no se rompe con él. El
   pisotón solo sirve como daño una vez que el enemigo ya no tiene armadura.
2. **La armadura solo cede al MELEE.** Un golpe de arma no baja HP mientras haya
   armadura: primero la rompe. Hace falta un segundo golpe (o un stomp posterior)
   para dañar el HP.
3. **El rebote del stomp es independiente de la armadura.** El bounce lo maneja
   el jugador, no `take_damage`; ver sección 4.

Ruptura de armadura:

```gdscript
func _break_armor() -> void:
	has_armor = false
	armor_broken.emit()
```

- Cambia el estado y emite la señal `armor_broken`.
- `BaseEnemy` **no** tiene sprite propio; las subclases reaccionan a la señal
  para actualizar su visual. El `.tscn` es la fuente de verdad del aspecto
  normal del enemigo.

---

## 4. Stomp (pisotón) — `EnemyBasic`

La detección de stomp está en `EnemyBasic`, vía un `Area2D` hijo llamado
`StompArea` colocado sobre la cabeza del enemigo.

```gdscript
func _on_stomp_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	if body.global_position.y < global_position.y:
		body.notify_stomp_hit()
		take_damage(1, DamageType.STOMP)
```

- **Detección por posición, no por velocidad.** Se comprueba que el jugador esté
  por encima (`body.global_position.y < global_position.y`). Usar
  `velocity.y > 0` es poco fiable porque `move_and_slide()` puede poner la
  velocidad a cero al aterrizar antes de que se disparen las señales del
  Area2D (decisión vigente #6 de la arquitectura).
- **El rebote es incondicional:** `body.notify_stomp_hit()` siempre rebota al
  jugador. La armadura detiene el daño, no el rebote.
- El daño de stomp está fijado en `1` (`take_damage(1, DamageType.STOMP)`).

---

## 5. Contacto letal lateral/inferior — `EnemyBasic`

El enemigo mata al jugador cuando lo toca desde el lado o desde abajo (casos que
el propio chequeo de colisión del jugador se pierde estando quieto).

```gdscript
func _check_player_contact() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is CharacterBody2D and (collider as CharacterBody2D).is_in_group("player"):
			if EnemyBasic.is_side_contact(collision.get_normal().y):
				LevelManager.handle_player_death()
				return

static func is_side_contact(normal_y: float) -> bool:
	return absf(normal_y) < 0.7
```

- Contactos casi verticales (normal_y ≥ 0.7 en magnitud) se consideran stomp
  (el jugador cayó encima) y se dejan a `StompArea`, no matan.
- Contactos laterales/inferiores (`|normal_y| < 0.7`) son letales: delegan en
  `LevelManager.handle_player_death()`. El enemigo no muta al jugador
  directamente.

---

## 6. Knockback

Estado y constantes en `BaseEnemy`:

```gdscript
const KNOCKBACK_SPEED: float = 200.0
const KNOCKBACK_DURATION: float = 0.12

var _knockback_velocity_x: float = 0.0
var _knockback_timer: float = 0.0

func apply_knockback(direction: float) -> void:
	_knockback_velocity_x = signf(direction) * KNOCKBACK_SPEED
	_knockback_timer = KNOCKBACK_DURATION
```

- `apply_knockback(direction)` empuja horizontalmente: `+1` derecha, `-1`
  izquierda, a `200 px/s` durante `0.12 s`.
- El timer es un float decrementado en `_physics_process` (decisión vigente #2:
  timers como floats, no nodos `Timer`).
- En `EnemyBasic._physics_process`, el knockback **domina sobre la patrulla**
  mientras dura: mientras `_knockback_timer > 0` el enemigo desliza en la
  dirección del empuje y se salta la lógica de dar la vuelta, para no revertir
  al instante al recibir el golpe.

```gdscript
if _knockback_timer > 0.0:
	_knockback_timer -= delta
	velocity.x = _knockback_velocity_x
	move_and_slide()
	_check_player_contact()
	return
```

---

## 7. Lado del arma del jugador — `MeleeAttack`

El daño MELEE lo dispara el hitbox del jugador, no el enemigo. `MeleeAttack` es
un `Area2D` hijo del jugador.

```gdscript
func _on_body_entered(body: Node2D) -> void:
	if weapon == null:
		return
	if body is BaseEnemy and not (body as Node).is_queued_for_deletion():
		if _already_hit.has(body):
			return
		_already_hit[body] = true
		var enemy := body as BaseEnemy
		enemy.take_damage(weapon.damage, BaseEnemy.DamageType.MELEE)
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.apply_knockback(signf(scale.x))
```

- El daño numérico viene del recurso `MeleeWeapon.damage` (por defecto `1`).
- **Un golpe por enemigo por swing:** `_already_hit` evita golpear dos veces al
  mismo enemigo durante el mismo ataque.
- **Knockback tras sobrevivir:** un enemigo que sobrevive al golpe (porque solo
  se le rompió la armadura) recibe `apply_knockback` en la dirección del swing.
  Un enemigo muerto ya fue liberado con `queue_free()`, así que se omite.
- El alcance del hitbox (`attack_offset` + ancho) supera el rango de muerte por
  contacto lateral, para que el jugador pueda golpear a un enemigo de suelo sin
  morir al tocarlo.

`MeleeWeapon` es solo datos:

```gdscript
@export var weapon_name: String = ""
@export var damage: int = 1
```

---

## 8. Visual de la armadura — `EnemyBasic`

```gdscript
const ARMOR_COLOR := Color(0.62, 0.66, 0.72)

func _ready() -> void:
	_spawn_position = global_position
	_base_color = $Sprite.color
	if has_armor:
		$Sprite.color = ARMOR_COLOR
	armor_broken.connect(_on_armor_broken)
	$StompArea.body_entered.connect(_on_stomp_area_body_entered)

func _on_armor_broken() -> void:
	$Sprite.color = _base_color
```

- Mientras `has_armor`, el `Sprite` (un `ColorRect`) se tinta con `ARMOR_COLOR`
  (gris azulado).
- Al romperse la armadura, vuelve a `_base_color`, que es el color definido en
  el `.tscn` (por defecto rojo `Color(0.8, 0.2, 0.2)`), manteniendo el `.tscn`
  como fuente de verdad del aspecto normal.

---

## 9. Valores por defecto (de `enemy_basic.tscn`)

| Propiedad | Valor por defecto | Fuente |
|---|---|---|
| `hp` | `1` | `BaseEnemy` (no sobreescrito en el `.tscn`) |
| `has_armor` | `false` | `BaseEnemy` (no sobreescrito en el `.tscn`) |
| Color normal del Sprite | `Color(0.8, 0.2, 0.2)` (rojo) | `enemy_basic.tscn` |
| Color con armadura | `Color(0.62, 0.66, 0.72)` | `EnemyBasic.ARMOR_COLOR` |
| Daño de stomp | `1` | `EnemyBasic` (fijo en `take_damage(1, ...)`) |
| Daño de melee | `1` | `MeleeWeapon.damage` (por defecto) |
| Velocidad de knockback | `200.0 px/s` | `BaseEnemy.KNOCKBACK_SPEED` |
| Duración de knockback | `0.12 s` | `BaseEnemy.KNOCKBACK_DURATION` |

---

## 10. Flujo de un enemigo con armadura (ejemplo)

1. Enemigo con `has_armor = true`, `hp = 1`. Sprite tintado de gris azulado.
2. El jugador **pisa** (STOMP): rebota, la armadura absorbe el daño, HP intacto.
3. El jugador **golpea** (MELEE): `_break_armor()` → `has_armor = false`, señal
   `armor_broken`, sprite vuelve a rojo, knockback en dirección del swing. HP
   intacto (aún `1`).
4. Segundo golpe efectivo (MELEE o STOMP): `hp -= 1` → `hp = 0` → `queue_free()`.

---

## Tests de referencia

Estos tests documentan y verifican el comportamiento anterior:

- `test/combat/test_weapon_hits_enemy.gd` — daño melee y ruptura de armadura.
- `test/combat/test_enemy_knockback.gd` — knockback.
- `test/combat/test_enemy_contact.gd` — muerte del jugador por contacto lateral.
