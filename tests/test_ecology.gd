@tool
extends SceneTree

const TerrainEcology = preload("res://world/vegetation/common/terrain_ecology.gd")

func _init() -> void:
	print("--- TEST DE TerrainEcology ---")
	var eco = TerrainEcology.new(12345)
	eco.generate_layout()
	print("Árboles generados: ", eco.trees.size())
	for i in range(eco.trees.size()):
		var t = eco.trees[i]
		print(" T%d [%s]: Pos %s, Radio %.2fm, Escala %.2f" % [i, t["profile_id"], t["position"], t["canopy_radius"], t["scale"]])
	
	# Probar consultas de suelo
	var test_points = [
		Vector2(-4.2, -4.5), # Dentro del bosque denso
		Vector2(0.0, -1.0),   # Pradera central
		Vector2(0.8, -5.8),   # Árbol solitario
	]
	for p in test_points:
		var info = eco.get_soil_info(p)
		print(" Punto %s -> Dirt: %.2f | Pasto Dens: %.2f | Flor Dens: %.2f | Dist Árbol: %.2fm" % [
			p, info["dirt_factor"], info["grass_density"], info["flower_density"], info["min_tree_dist"]
		])
	quit(0)
