@tool
extends SceneTree

const ForestModelUtils = preload("res://world/forest_model_utils.gd")

func _init() -> void:
	print("--- PRUEBA DE EXTRACCIÓN DE PSX_Grass ---")
	var utils = ForestModelUtils.new()
	var grass_node = utils.get_model(ForestModelUtils.MODEL_GRASS, 0.45)
	if grass_node:
		print("Nodo de pasto obtenido: ", grass_node)
		print("Hijos: ", grass_node.get_child_count())
		for c in grass_node.get_children():
			if c is MeshInstance3D:
				print(" - Mesh: ", c.mesh)
				print(" - Transform local: ", c.transform)
				var aabb = c.mesh.get_aabb()
				print(" - AABB: ", aabb)
				print(" - AABB transformado: ", c.transform * aabb)
		grass_node.free()
	else:
		print("ERROR: No se pudo obtener PSX_Grass")
	quit(0)
