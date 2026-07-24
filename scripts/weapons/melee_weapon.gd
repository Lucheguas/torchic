class_name MeleeWeapon
extends Resource
## Data-only resource describing a melee weapon.
## Damage is applied by a MeleeAttack node when the player triggers the weapon.

@export var weapon_name: String = ""
@export var damage: int = 1
