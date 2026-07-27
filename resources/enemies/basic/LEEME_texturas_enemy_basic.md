# Texturas del EnemyBasic (normal y con armadura)

Es un solo enemigo: `EnemyBasic` (escena `scenes/enemy_basic.tscn`). La versión
"con armadura" es la misma instancia con `has_armor = true`. Asigna las imágenes
en el Inspector del nodo `EnemyBasic`.

Ranuras del Inspector → imagen:

Grupo "Texturas: caminar (normal)"  (sin armadura, y también tras romperla)
- `walk_right_a` → caminar a la derecha, pie derecho adelante
- `walk_right_b` → caminar a la derecha, pie izquierdo adelante
- `walk_left_a`  → caminar a la izquierda, pie derecho adelante
- `walk_left_b`  → caminar a la izquierda, pie izquierdo adelante

Grupo "Texturas: caminar (con armadura)"
- `armor_walk_right_a` → con armadura, a la derecha, pie derecho adelante
- `armor_walk_right_b` → con armadura, a la derecha, pie izquierdo adelante
- `armor_walk_left_a`  → con armadura, a la izquierda, pie derecho adelante
- `armor_walk_left_b`  → con armadura, a la izquierda, pie izquierdo adelante

Comportamiento:
- Con armadura → usa el set "con armadura".
- Al romperse la armadura → cambia al set "normal".
- Un enemigo que nunca lleva armadura solo necesita el set normal (4 imágenes).
- Uno con armadura necesita los dos sets (8 imágenes).

Notas:
- Hasta que estén las 4 del set que toca, el enemigo se dibuja con el ColorRect
  (fallback): rojo si no tiene armadura, gris si la tiene.
- Tras asignarlas, ajusta `scale`/`position` del nodo hijo `Anim` (Sprite2D)
  según el tamaño real del pixel art.
