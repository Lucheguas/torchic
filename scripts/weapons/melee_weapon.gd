class_name MeleeWeapon
extends Resource
## Data-only resource describing a melee weapon.
## Damage is applied by a MeleeAttack node when the player triggers the weapon.

@export var weapon_name: String = ""
@export var damage: float = 1.0
## Icon shown when the weapon rests on the ground (pedestal or dropped item).
## Optional: a weapon without a texture falls back to a plain colored block.
@export var texture: Texture2D
