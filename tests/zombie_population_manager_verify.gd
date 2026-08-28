extends Node3D
## Verifica que el gestor mantenga poblacion agregada y limite los nodos activos.

@onready var manager: Node3D = $ZombiePopulationManager
@onready var player: Node3D = $Player

var _elapsed := 0.0
var _initial_total := -1
var _death_requested := false


func _ready() -> void:
	player.add_to_group("players")
	manager.max_active_zombies = 1
	manager.configure_world(9876)


func _process(delta: float) -> void:
	_elapsed += delta
	var total: int = manager.get_total_population()
	var active: int = manager.get_active_zombie_count()
	if _initial_total < 0 and total >= 648 and active == 1:
		_initial_total = total
		manager.set_process(false)
		for child in manager.get_children():
			if child.has_method("take_damage"):
				child.take_damage(60.0)
				_death_requested = true
				break

	if _death_requested and active == 0 and total == _initial_total - 1:
		print("[verify] OK: poblacion agregada=%d, muerte retiro un zombie" % _initial_total)
		get_tree().quit(0)
		return
	if _elapsed > 8.0:
		print("[verify] FALLO: poblacion=%d activos=%d" % [total, active])
		get_tree().quit(1)