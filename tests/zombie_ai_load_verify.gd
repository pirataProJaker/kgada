extends SceneTree
## Benchmark liviano: mide IA Rust sin crear nodos visuales ni fisica Godot.

const POPULATION_SIZES := [50, 100, 250, 500, 1000]
const TICKS := 60


func _initialize() -> void:
	if not ClassDB.class_exists("ZombieAi"):
		print("[verify] FALLO: ZombieAi no existe")
		quit(1)
		return

	for population_size in POPULATION_SIZES:
		var agents: Array = []
		for index in population_size:
			var ai = ClassDB.instantiate("ZombieAi")
			ai.call("set_seed", index + population_size)
			ai.call("set_speed", 1.0)
			agents.append(ai)

		var started_at := Time.get_ticks_usec()
		for tick_index in TICKS:
			for ai in agents:
				ai.call("tick", 1.0 / 60.0)
		var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
		print("[verify] load agents=%d ticks=%d elapsed_ms=%.2f" % [population_size, TICKS, elapsed_ms])

		for ai in agents:
			ai.free()

	print("[verify] OK: carga Rust 50/100/250/500/1000 completada")
	quit(0)