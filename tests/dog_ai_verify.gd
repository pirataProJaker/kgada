extends SceneTree
## Verifica que DogAi (Rust) alterna entre caminar y pausa.
##   godot --headless --path . -s tests/dog_ai_verify.gd

func _initialize() -> void:
	if not ClassDB.class_exists("DogAi"):
		print("[verify] FALLO: DogAi no existe (el DLL de Rust no cargo)")
		quit(1)
		return

	var ai = ClassDB.instantiate("DogAi")
	ai.call("set_speed", 1.8)

	# Simular muchos ticks y contar cuantos devuelven velocidad 0 (pausa)
	# vs velocidad != 0 (caminando). Con pausas de 1.5-4s y caminar de 2-5s,
	# debe haber una mezcla de ambos.
	var zero_count := 0
	var move_count := 0
	var delta := 1.0 / 60.0
	for i in 2000:
		var v: Vector3 = ai.call("tick", delta)
		if v.length() < 0.001:
			zero_count += 1
		else:
			move_count += 1

	print("[verify] ticks con velocidad 0 (pausa): %d" % zero_count)
	print("[verify] ticks con velocidad != 0 (caminando): %d" % move_count)

	if zero_count > 0 and move_count > 0:
		print("[verify] OK: la IA alterna entre caminar y pausa")
		quit(0)
	else:
		print("[verify] FALLO: la IA no alterna (solo %s)" % ("pausa" if zero_count > 0 else "caminar"))
		quit(1)
