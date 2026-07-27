# Texturas del EnemyCharger

Pon aquí las 8 imágenes del enemigo que embiste y asígnalas en el Inspector del
nodo `EnemyCharger` (mejor en la escena `scenes/enemy_charger.tscn` para que
apliquen a todas las instancias).

Ranuras del Inspector → imagen:

Grupo "Texturas: caminar"
- `walk_right_a`  → caminar a la derecha, pie derecho adelante
- `walk_right_b`  → caminar a la derecha, pie izquierdo adelante
- `walk_left_a`   → caminar a la izquierda, pie derecho adelante
- `walk_left_b`   → caminar a la izquierda, pie izquierdo adelante

Grupo "Texturas: embestir"
- `charge_right_a` → embestir a la derecha, pie derecho adelante
- `charge_right_b` → embestir a la derecha, pie izquierdo adelante
- `charge_left_a`  → embestir a la izquierda, pie derecho adelante
- `charge_left_b`  → embestir a la izquierda, pie izquierdo adelante

Notas:
- Hasta que estén las 8, el enemigo se dibuja con el ColorRect naranja (fallback).
- Tras asignarlas, ajusta `scale`/`position` del nodo hijo `Anim` (Sprite2D) según
  el tamaño real del pixel art, como en el Sprite2D del jugador.
