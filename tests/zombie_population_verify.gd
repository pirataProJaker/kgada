extends SceneTree
## Verifica el registro Rust de poblacion por sectores.
##   godot --headless --path . -s tests/zombie_population_verify.gd

func _initialize() -> void:
	if not ClassDB.class_exists("ZombiePopulation"):
		print("[verify] FALLO: ZombiePopulation no existe")
		quit(1)
		return

	var population = ClassDB.instantiate("ZombiePopulation")
	population.call("configure", 80.0, 12345)

	if population.call("get_sector_size") != 80.0:
		print("[verify] FALLO: tamano de sector incorrecto")
		quit(1)
		return

	var sector: Vector2i = population.call("world_to_sector", Vector3(-0.1, 0.0, 80.0))
	if sector != Vector2i(-1, 1):
		print("[verify] FALLO: coordenada de sector incorrecta: %s" % sector)
		quit(1)
		return

	population.call("set_sector_population", 2, -1, 10)
	population.call("add_sector_population", 2, -1, 5)
	var removed: int = population.call("remove_sector_population", 2, -1, 3)
	var snapshot: Dictionary = population.call("get_sector_snapshot", 2, -1)
	var seed_a: int = population.call("get_sector_seed", 2, -1)
	var seed_b: int = population.call("get_sector_seed", 2, -1)

	if removed != 3 or snapshot.get("count", -1) != 12:
		print("[verify] FALLO: operaciones de poblacion incorrectas: %s" % snapshot)
		quit(1)
		return

	if population.call("get_total_population") != 12 or population.call("get_sector_count") != 1:
		print("[verify] FALLO: totales incorrectos")
		quit(1)
		return

	if seed_a != seed_b or snapshot.get("seed", 0) != seed_a:
		print("[verify] FALLO: semilla de sector no determinista")
		quit(1)
		return

	population.call("set_sector_aggregate_state", 2, -1, 2, Vector2(1.0, -0.5))
	population.call("report_sector_noise", 2, -1, Vector3(4.0, 0.0, 5.0), 0.8, 2.0)
	snapshot = population.call("get_sector_snapshot", 2, -1)
	if snapshot.get("state", -1) != 1 or snapshot.get("noise_strength", 0.0) <= 0.0:
		print("[verify] FALLO: estado agregado/ruido no guardado: %s" % snapshot)
		quit(1)
		return

	population.call("advance", 2.5)
	snapshot = population.call("get_sector_snapshot", 2, -1)
	if snapshot.get("noise_strength", -1.0) != 0.0 or snapshot.get("noise_remaining", -1.0) != 0.0:
		print("[verify] FALLO: ruido no expiro: %s" % snapshot)
		quit(1)
		return

	population.call("clear")
	if population.call("get_total_population") != 0 or population.call("get_sector_count") != 0:
		print("[verify] FALLO: clear no vacio el registro")
		quit(1)
		return

	print("[verify] OK: registro de poblacion por sectores funciona")
	population.free()
	quit(0)