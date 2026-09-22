extends SceneTree

const FlowerGenerator = preload("res://world/procedural_flora/procedural_flower_generator.gd")

func _init() -> void:
	# Simular las tiradas de skel_rng para seed 13344
	var skel_rng = RandomNumberGenerator.new()
	skel_rng.seed = 13344
	# 1. Basal shoots (4)
	for b in range(4):
		skel_rng.randf_range(-0.25, 0.25)
		skel_rng.randf_range(0.38, 0.50)
		skel_rng.randf_range(0.80, 0.95)
	# 2. Outer canes (5)
	for i in range(5):
		skel_rng.randf_range(-0.2, 0.2)
		skel_rng.randf_range(0.80, 0.90)
		skel_rng.randf_range(0.42, 0.52)
	# 3. Inner canes (2)
	for i in range(2):
		skel_rng.randf_range(0.3, 0.8)
		skel_rng.randf_range(0.95, 1.02)
		skel_rng.randf_range(0.12, 0.20)
	# 4. Canes loop
	var flower_idx = 0
	for c_idx in range(7):
		skel_rng.randf_range(0.92, 1.15)
		if c_idx < 5 and (c_idx % 2 == 0):
			# Branch flower
			var s_roll = skel_rng.randf()
			var s_scale = 1.0 if s_roll < 0.75 else skel_rng.randf_range(0.65, 0.85)
			print("Flower ", flower_idx, " (Branch of cane ", c_idx, "): s_roll=", s_roll, " scale=", s_scale)
			flower_idx += 1
		# Terminal flower
		var t_roll = skel_rng.randf()
		var type = "BLOOM"
		if t_roll < 0.70:
			type = "BLOOM (full)"
		elif t_roll < 0.90:
			var sc = skel_rng.randf_range(0.65, 0.85)
			type = "BLOOM (semi %.2f)" % sc
		else:
			type = "BUD (closed capullo!)"
		print("Flower ", flower_idx, " (Terminal cane ", c_idx, "): t_roll=", t_roll, " -> ", type)
		flower_idx += 1
	quit(0)
