extends Node3D
## Verifica vision, collider, evento de ataque y cooldown usando escenas reales.

@onready var stats: Node = $Player/PlayerStats
@onready var zombie: Node3D = $Zombie

var _elapsed := 0.0
var _initial_health := 100.0
var _first_hit_health := -1.0


func _ready() -> void:
	_initial_health = stats.health


func _process(delta: float) -> void:
	_elapsed += delta
	if _first_hit_health < 0.0 and stats.health < _initial_health:
		_first_hit_health = stats.health
		if _first_hit_health > _initial_health - 7.0 or _first_hit_health < _initial_health - 8.5:
			print("[verify] FALLO: dano inicial inesperado: %s" % _first_hit_health)
			get_tree().quit(1)
			return
		var zombie_state: Dictionary = zombie.get_network_state()
		if zombie_state.get("animation", "") != "attack":
			print("[verify] FALLO: animacion de ataque no activa: %s" % zombie_state)
			get_tree().quit(1)
			return

	if _first_hit_health >= 0.0 and _elapsed >= 0.45:
		if stats.health < _first_hit_health - 0.01:
			print("[verify] FALLO: dano repetido durante cooldown: %s -> %s" % [_first_hit_health, stats.health])
			get_tree().quit(1)
			return
		print("[verify] OK: ataque aplica un golpe y respeta cooldown")
		get_tree().quit(0)
		return

	if _elapsed > 4.0:
		print("[verify] FALLO: zombie no aplico dano; vida=%s" % stats.health)
		get_tree().quit(1)