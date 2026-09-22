extends SceneTree

## Test unitario y de conteo de geometría para el sistema modular de vegetación

const WildDaisy = preload("res://world/vegetation/daisy/wild_daisy.gd")
const WildLavender = preload("res://world/vegetation/lavender/wild_lavender.gd")
const TriangleGrass = preload("res://world/vegetation/grass/triangle_grass.gd")
const WildPoppy = preload("res://world/vegetation/poppy/wild_poppy.gd")

func _init() -> void:
	print("--- VERIFICACIÓN DEL SISTEMA MODULAR DE VEGETACIÓN ---")
	
	# 1. WildDaisy
	var daisy_mesh = WildDaisy.create_mesh(12345)
	var daisy_tris = _count_mesh_triangles(daisy_mesh)
	print("✓ WildDaisy creada: %d triángulos" % daisy_tris)
	assert(daisy_tris > 20 and daisy_tris < 60, "Conteo de triángulos de margarita fuera de rango")
	
	# 2. WildLavender
	var lavender_mesh = WildLavender.create_mesh(12345)
	var lavender_tris = _count_mesh_triangles(lavender_mesh)
	print("✓ WildLavender creada: %d triángulos" % lavender_tris)
	assert(lavender_tris > 35 and lavender_tris < 85, "Conteo de triángulos de lavanda fuera de rango")
	
	# 3. TriangleGrass
	var grass_mesh = TriangleGrass.create_mesh(12345)
	var grass_tris = _count_mesh_triangles(grass_mesh)
	print("✓ TriangleGrass creada: %d triángulos" % grass_tris)
	assert(grass_tris > 8 and grass_tris < 25, "Conteo de triángulos de césped fuera de rango")
	
	# 4. WildPoppy
	var poppy_mesh = WildPoppy.create_mesh(12345)
	var poppy_tris = _count_mesh_triangles(poppy_mesh)
	print("✓ WildPoppy creada: %d triángulos" % poppy_tris)
	assert(poppy_tris > 15 and poppy_tris < 45, "Conteo de triángulos de amapola fuera de rango")
	
	print("\n=== TODAS LAS PRUEBAS DE VEGETACIÓN PASARON CON ÉXITO ===")
	quit(0)

func _count_mesh_triangles(mesh: ArrayMesh) -> int:
	if mesh == null:
		return 0
	var total: int = 0
	for s in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			total += arrays[Mesh.ARRAY_INDEX].size() / 3
		elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			total += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return total
