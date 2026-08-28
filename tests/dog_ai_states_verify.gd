extends SceneTree
## Verifica que DogAi (Rust) devuelve velocity + anim con los estados
## walk/run/idle/sit/lay.
##   godot --headless --path . -s tests/dog_ai_states_verify.gd

func _initialize() -> void:
	if not ClassDB.class_exists("DogAi"):
		print("[verify] FALLO: DogAi no existe (el DLL de Rust no cargo)")
		quit(1)
		return

	var ai = ClassDB.instantiate("DogAi")
	ai.call("set_speed", 1.8)

	# Simular muchos ticks y recolectar los estados/animaciones vistos.
	var anims_seen := {}
	var moving_count := 0
	var still_count := 0
	var delta := 1.0 / 60.0
	for i in 20000:
		var result: Dictionary = ai.call("tick", delta)
		var v: Vector3 = result.get("velocity", Vector3.ZERO)
		var anim: String = result.get("anim", "")
		anims_seen[anim] = true
		if v.length() > 0.001:
			moving_count += 1
		else:
			still_count += 1

	print("[verify] animaciones vistas: %s" % anims_seen.keys())
	print("[verify] ticks moviendose: %d, quieto: %d" % [moving_count, still_count])

	# Debe haber al menos walk, run, idle, sit, lay
	var expected := ["Dog1_Walk", "Dog1_Run", "Dog1_Idle", "Dog1_Sit", "Dog1_Lay"]
	var missing := []
	for e in expected:
		if not anims_seen.has(e):
			missing.append(e)

	if missing.is_empty() and moving_count > 0 and still_count > 0:
		print("[verify] OK: la IA usa todos los estados")
		quit(0)
	else:
		print("[verify] FALLO: faltan animaciones %s" % missing)
		quit(1)
