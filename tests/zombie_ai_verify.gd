extends SceneTree
## Verifica los estados principales de ZombieAi en Rust.
##   godot --headless --path . -s tests/zombie_ai_verify.gd

const EXPECTED_CHASE_SPEED := 4.5 * 0.95


func _initialize() -> void:
	if not ClassDB.class_exists("ZombieAi"):
		print("[verify] FALLO: ZombieAi no existe")
		quit(1)
		return

	var ai = ClassDB.instantiate("ZombieAi")
	ai.call("set_speed", EXPECTED_CHASE_SPEED)
	ai.call("set_seed", 42)

	var idle_ticks := 0
	var wander_ticks := 0
	var delta := 1.0 / 60.0
	for i in 1200:
		ai.call("set_perception", Vector3.ZERO, Vector3.ZERO, false, false, Vector3.ZERO)
		var unalerted: Dictionary = ai.call("tick", delta)
		if unalerted.get("state", "") == "idle":
			idle_ticks += 1
		elif unalerted.get("state", "") == "wander":
			wander_ticks += 1

	if idle_ticks <= wander_ticks or idle_ticks < 300:
		print("[verify] FALLO: idle no predomina: idle=%d wander=%d" % [idle_ticks, wander_ticks])
		quit(1)
		return

	ai.call("set_perception", Vector3.ZERO, Vector3(0.0, 0.0, 5.0), true, false, Vector3.ZERO)
	var chase: Dictionary = ai.call("tick", delta)
	var chase_velocity: Vector3 = chase.get("velocity", Vector3.ZERO)
	var chase_speed := Vector2(chase_velocity.x, chase_velocity.z).length()
	if chase.get("state", "") != "chase" or chase.get("anim", "") != "run":
		print("[verify] FALLO: no persigue al objetivo visible: %s" % chase)
		quit(1)
		return
	if absf(chase_speed - EXPECTED_CHASE_SPEED) > 0.01:
		print("[verify] FALLO: velocidad de persecucion inesperada: %.3f" % chase_speed)
		quit(1)
		return

	ai.call("set_perception", Vector3.ZERO, Vector3(0.0, 0.0, 5.0), false, false, Vector3.ZERO)
	var investigate: Dictionary = {}
	for i in 20:
		investigate = ai.call("tick", delta)
	if investigate.get("state", "") != "investigate":
		print("[verify] FALLO: no investiga la ultima posicion: %s" % investigate)
		quit(1)
		return

	ai.call("set_perception", Vector3.ZERO, Vector3(0.0, 0.0, 1.0), true, false, Vector3.ZERO)
	var attack: Dictionary = ai.call("tick", delta)
	if attack.get("state", "") != "attack" or not attack.get("attack", false):
		print("[verify] FALLO: no emite ataque: %s" % attack)
		quit(1)
		return

	var cooldown: Dictionary = ai.call("tick", delta)
	if cooldown.get("attack", false):
		print("[verify] FALLO: ataque repetido durante cooldown")
		quit(1)
		return

	var noise_ai = ClassDB.instantiate("ZombieAi")
	noise_ai.call("set_seed", 7)
	noise_ai.call("hear_noise", Vector3(3.0, 0.0, 2.0), 1.0)
	var noise_result: Dictionary = noise_ai.call("tick", delta)
	if noise_result.get("state", "") != "investigate":
		print("[verify] FALLO: no investiga ruido agregado: %s" % noise_result)
		quit(1)
		return

	print("[verify] OK: ZombieAi idle/chase/investigate/attack funciona")
	ai.free()
	noise_ai.free()
	quit(0)