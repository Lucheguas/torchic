extends CanvasLayer
## In-game HUD. Shows the remaining lives as hearts in the top-left corner and
## updates whenever LevelManager reports a change: a lost life empties a heart.

const HEART_SHEET: Texture2D = preload("res://Inventory_Light_Herat_Spritesheet.png")

## Regions of the 32x32 heart cells in the spritesheet: the sheet's large heart
## row holds empty / half / full states side by side. Only empty and full are
## used: a life is either there or spent.
const FULL_HEART_REGION := Rect2(64, 48, 32, 32)
const EMPTY_HEART_REGION := Rect2(0, 48, 32, 32)

var _full_heart: AtlasTexture
var _empty_heart: AtlasTexture
var _hearts: Array[TextureRect] = []


func _ready() -> void:
	_full_heart = _make_heart(FULL_HEART_REGION)
	_empty_heart = _make_heart(EMPTY_HEART_REGION)
	for heart in $Hearts.get_children():
		_hearts.append(heart as TextureRect)
	LevelManager.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(LevelManager.get_lives())


func _make_heart(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HEART_SHEET
	atlas.region = region
	return atlas


func _on_lives_changed(lives: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = _full_heart if i < lives else _empty_heart
