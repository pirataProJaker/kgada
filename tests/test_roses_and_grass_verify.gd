extends SceneTree

const ChunkManager = preload("res://world/chunk_manager.gd")

func _init() -> void:
	print("--- INICIANDO TEST DE ROSAS Y GRASS REDUCIDO EN CHUNK MANAGER ---")
	var root_node = Node3D.new()
	var cm = ChunkManager.new()
	root_node.add_child(cm)
	
	# Llamar _ready manualmente o al entrar al arbol
	print("Pool de rosas precalculadas: %d" % cm._rose_archetype_pool.size())
	assert(cm._rose_archetype_pool.size() == 18, "El pool de rosas debe tener exactamente 18 arquetipos")
	
	# Simular chunk en (0, 0)
	var dummy_parent = Node3D.new()
	root_node.add_child(dummy_parent)
	
	var data: Dictionary = {
		"rose_requests": [
			{
				"pos": Vector3(5, 0, 5),
				"scale": Vector3.ONE,
				"rot_y": 0.5,
				"pool_index": 0
			},
			{
				"pos": Vector3(10, 0, 10),
				"scale": Vector3.ONE * 1.2,
				"rot_y": 1.2,
				"pool_index": 5
			}
		]
	}
	
	var spawned = cm._spawn_chunk_roses(Vector2i(0, 0), dummy_parent, data)
	print("Rosas encoladas para attach: %d (cola tiene %d items)" % [spawned, cm._rose_attach_queue.size()])
	assert(spawned == 2, "Deben haberse encolado 2 rosas")
	assert(cm._rose_attach_queue.size() == 2, "La cola debe tener 2 items")
	
	# Procesar cola
	cm._process_rose_attachments()
	print("Despues de 1 frame de attachments: cola restante = %d, hijos en dummy_parent = %d" % [
		cm._rose_attach_queue.size(), dummy_parent.get_child_count()
	])
	assert(dummy_parent.get_child_count() == 2, "Deben haberse adjuntado 2 rosales al parent")
	
	var first_rose = dummy_parent.get_child(0)
	assert(first_rose.name.begins_with("ChunkRose"), "El nombre del nodo debe ser ChunkRose")
	assert(first_rose.has_node("LOD0"), "El rosal debe tener nodo LOD0")
	assert(first_rose.has_node("LOD1"), "El rosal debe tener nodo LOD1")
	assert(first_rose.has_node("LOD2"), "El rosal debe tener nodo LOD2")
	print("✓ Rosal instanciado correctamente con sus 3 niveles de LOD procedurales")
	
	root_node.free()
	print("\n=== TEST DE ROSAS Y CHUNK MANAGER COMPLETADO CON EXITO ===")
	quit(0)
