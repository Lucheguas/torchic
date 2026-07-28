class_name TransitionTrigger
extends PlayerTrigger
## Trigger de fin de tramo: al entrar el jugador emite `triggered(self)` y el
## LevelManager decide qué cargar según el estado (fin de piso → entre_nivel,
## salida del entre_nivel → siguiente piso).

signal triggered(trigger: TransitionTrigger)


func _on_player_entered(_body: Node2D) -> void:
	triggered.emit(self)
