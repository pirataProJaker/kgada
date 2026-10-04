extends SceneTree

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const WoodenTableScript = preload("res://world/furniture/wooden_table.gd")
const WoodenChairScript = preload("res://world/furniture/wooden_chair.gd")
const DiningSetScript = preload("res://world/furniture/dining_set.gd")

func _init() -> void:
	print("--- TEST MOBILIARIO GPU MULTIMESH & TEXTURE ARRAY ---")
	
	# 1. Test Texture Manager
	FurnitureTextureManagerScript.ensure_initialized()
	var wood_keys := FurnitureTextureManagerScript.get_all_wood_keys()
	print("Claves de madera registradas: ", wood_keys)
	assert(wood_keys.size() >= 2, "Debe haber al menos 2 acabados de madera")
	
	for key in wood_keys:
		var layer := FurnitureTextureManagerScript.get_wood_layer(key)
		print("  - Acabado: %s -> Capa %d" % [key, layer])
	
	var mat := FurnitureTextureManagerScript.get_shared_material()
	assert(mat != null, "Material compartido no debe ser nulo")
	print("✓ Material compartido de maderas verificado.")

	# 2. Test Shared Meshes
	var chair_mesh := WoodenChairScript.get_shared_mesh()
	assert(chair_mesh != null, "Malla compartida de silla no debe ser nula")
	print("✓ Malla compartida de silla: caras = ", chair_mesh.get_faces().size() / 3)

	var table_mesh := WoodenTableScript.get_shared_mesh()
	assert(table_mesh != null, "Malla compartida de mesa no debe ser nula")
	print("✓ Malla compartida de mesa: caras = ", table_mesh.get_faces().size() / 3)

	# 3. Test MultiMesh System con lote masivo (10 comedores = 10 mesas, 40 sillas)
	var root_node := Node3D.new()
	root.add_child(root_node)

	var sys := FurnitureMultiMeshSystemScript.new()
	root_node.add_child(sys)

	for i in range(10):
		var t := Transform3D(Basis.IDENTITY, Vector3(float(i) * 3.0, 0.0, 0.0))
		sys.add_dining_set(t, i % wood_keys.size(), 4)

	assert(sys.get_table_count() == 10, "Debe haber 10 mesas registradas")
	assert(sys.get_chair_count() == 40, "Debe haber 40 sillas registradas")
	
	sys.build(true)
	
	var tables_mm: MultiMeshInstance3D = sys.get_node_or_null("TablesMultiMesh")
	var chairs_mm: MultiMeshInstance3D = sys.get_node_or_null("ChairsMultiMesh")
	var col_body: StaticBody3D = sys.get_node_or_null("FurnitureCollision")

	assert(tables_mm != null, "TablesMultiMesh debe existir")
	assert(tables_mm.multimesh.instance_count == 10, "Tables MultiMesh debe tener 10 instancias")
	assert(chairs_mm != null, "ChairsMultiMesh debe existir")
	assert(chairs_mm.multimesh.instance_count == 40, "Chairs MultiMesh debe tener 40 instancias")
	assert(col_body != null, "FurnitureCollision debe existir")
	
	# Cada mesa tiene 5 cajas (cubierta + 4 patas) = 5 * 10 = 50
	# Cada silla tiene 2 cajas (asiento + respaldo) = 2 * 40 = 80
	# Total esperado = 130 colisiones físicas exactas
	print("Colisiones físicas generadas en StaticBody3D: ", col_body.get_child_count())
	assert(col_body.get_child_count() == 130, "Debe haber exactamente 130 cajas de colisión")

	print("✓ Test de GPU MultiMesh & Texture Array COMPLETADO EXITOSAMENTE.")
	quit(0)
