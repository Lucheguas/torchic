class_name WeaponPickup
extends Area2D
## A weapon resting on the ground (a pedestal in the entre-nivel, or an item the
## player dropped). While the player overlaps it, pressing E takes this weapon
## and swaps the player's current one back onto the pickup. A pickup left empty
## (the player was unarmed) removes itself from the ground.

@export var weapon: MeleeWeapon
## Whether to show the weapon name + "[E]" prompt. Pedestals show it; weapons the
## player drops on the ground hide it (just the item, no label).
@export var show_label: bool = true

## On-screen height (px) for the weapon icon. Kept below the player's height so a
## dropped weapon never looks bigger than the character.
const ICON_HEIGHT: float = 26.0

@onready var _label: Label = $Label
@onready var _visual: ColorRect = $Visual
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("set_nearby_pickup"):
		body.set_nearby_pickup(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("clear_nearby_pickup"):
		body.clear_nearby_pickup(self)


## Puts a weapon on the pickup (the player's old one during a swap). A null
## weapon means the pickup is now empty, so it removes itself from the ground.
func set_weapon(new_weapon: MeleeWeapon) -> void:
	weapon = new_weapon
	if weapon == null:
		queue_free()
		return
	_refresh()


## Shows the weapon's own texture when it has one; otherwise falls back to the
## plain colored block (weapons without art yet, e.g. lanza/katana).
func _refresh() -> void:
	if weapon == null:
		return
	if _label:
		_label.visible = show_label
		_label.text = weapon.weapon_name + "\n[E]"
	if weapon.texture != null:
		_icon.texture = weapon.texture
		var h := weapon.texture.get_height()
		if h > 0:
			var s := ICON_HEIGHT / float(h)
			_icon.scale = Vector2(s, s)
		_icon.visible = true
		_visual.visible = false
	else:
		_icon.visible = false
		_visual.visible = true
