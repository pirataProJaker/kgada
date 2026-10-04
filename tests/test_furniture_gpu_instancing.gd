extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("INICIANDO PRUEBA DE GPU INSTANCING + ATLAS INTELIGENTE DE MUEBLES")
	print("==================================================================")

	var tex_mgr = load("res://world/furniture/furniture_texture_manager.gd")
	if tex_mgr == null:
		printerr("FAIL: No se pudo cargar FurnitureTextureManager")
		quit(1)
		return

	tex_mgr.ensure_initialized()
	var keys = tex_mgr.get_all_keys()
	print("[1/4] Claves semánticas en Atlas Inteligente: ", keys)
	var expected_keys := [
		"roble_claro", "nogal_oscuro", "caoba_rojiza", "pino_natural",
		"refrigerador", "estufa", "microondas", "cabinets", "toaster",
		"coffee_table", "washer", "dryer", "sofa_leather"
	]
	for k in expected_keys:
		var layer_idx = tex_mgr.get_texture_layer(k)
		print("  -> Clave '%s' asignada a Capa %d" % [k, layer_idx])

	var mat = tex_mgr.get_shared_material()
	if mat == null:
		printerr("FAIL: Shared material es nulo")
		quit(1)
		return
	print("[1/4] ✓ Material Shader universal instanciado correctamente.")

	print("\n[2/4] Verificando mallas compartidas y colisiones de cada clase:")
	var classes_to_test := {
		"WoodenTable": load("res://world/furniture/wooden_table.gd"),
		"WoodenChair": load("res://world/furniture/wooden_chair.gd"),
		"ApplianceRefrigerator": load("res://world/furniture/appliance_refrigerator.gd"),
		"ApplianceStove": load("res://world/furniture/appliance_stove.gd"),
		"ApplianceMicrowave": load("res://world/furniture/appliance_microwave.gd"),
		"KitchenCabinet (Base)": load("res://world/furniture/kitchen_cabinet.gd"),
		"KitchenCabinet (Wall)": load("res://world/furniture/kitchen_cabinet.gd"),
		"ApplianceToaster": load("res://world/furniture/appliance_toaster.gd"),
		"CoffeeTable": load("res://world/furniture/coffee_table.gd"),
		"ApplianceWasher": load("res://world/furniture/appliance_washer.gd"),
		"ApplianceDryer": load("res://world/furniture/appliance_dryer.gd"),
		"ArmchairLeather": load("res://world/furniture/armchair_leather.gd")
	}

	for cname in classes_to_test:
		var scr = classes_to_test[cname]
		if scr == null:
			printerr("FAIL: Clase '%s' es nula" % cname)
			quit(1)
			return

		var mesh: ArrayMesh = null
		var boxes: Array[Dictionary] = []

		if cname == "KitchenCabinet (Base)":
			mesh = scr.get_shared_mesh(0)
			boxes = scr.get_collision_boxes(0)
		elif cname == "KitchenCabinet (Wall)":
			mesh = scr.get_shared_mesh(1)
			boxes = scr.get_collision_boxes(1)
		else:
			mesh = scr.get_shared_mesh()
			boxes = scr.get_collision_boxes()

		if mesh == null or mesh.get_surface_count() == 0:
			printerr("FAIL: Malla nula o vacía para ", cname)
			quit(1)
			return
		if boxes.is_empty():
			printerr("FAIL: Cajas de colisión vacías para ", cname)
			quit(1)
			return

		print("  ✓ %s: Malla válida (%d vértices en surf 0), %d cajas de colisión" % [
			cname, mesh.surface_get_array_len(0), boxes.size()
		])

	print("\n[3/4] Verificando FurnitureMultiMeshSystem:")
	var fms_class = load("res://world/furniture/furniture_multimesh_system.gd")
	var fms = fms_class.new()
	root.add_child(fms)

	# Agregar 10 instancias de cada mueble
	for i in range(10):
		var t := Transform3D(Basis.IDENTITY, Vector3(float(i) * 2.0, 0.0, 0.0))
		fms.add_table(t, 0)
		fms.add_chair(t, 1)
		fms.add_refrigerator(t)
		fms.add_stove(t)
		fms.add_microwave(t)
		fms.add_cabinet_base(t)
		fms.add_cabinet_wall(t)
		fms.add_toaster(t)
		fms.add_coffee_table(t)
		fms.add_washer(t)
		fms.add_dryer(t)
		fms.add_armchair(t)
		fms.add_primitive_cube(t, "roble_claro")
		fms.add_primitive_cylinder(t, "metal")
		fms.add_primitive_prism(t, "sofa_leather")

	print("  Muebles registrados: %d" % fms.get_total_furniture_count())
	fms.build(true)
	var active_dc: int = fms.get_active_multimesh_count()
	print("  Draw Calls activas en MultiMesh: %d" % active_dc)
	var col = fms.get_node_or_null("FurnitureCollision")
	var col_count: int = col.get_child_count() if col else 0
	print("  Formas de colisión generadas: %d" % col_count)

	if active_dc == 0 or col_count == 0:
		printerr("FAIL: No se generaron multimeshes o colisiones en FurnitureMultiMeshSystem")
		quit(1)
		return

	print("\n[4/4] Verificando inicialización de escena Showcase:")
	var showcase_scr = load("res://scenes/cross_street_houses_showcase.gd")
	var showcase = showcase_scr.new()
	root.add_child(showcase)
	# Esperar un frame
	await process_frame
	print("  ✓ Escena Showcase instanciada y ejecutada exitosamente.")

	print("\n==================================================================")
	print("✓ TODAS LAS PRUEBAS DE GPU INSTANCING + ATLAS COMPLETADAS CON ÉXITO")
	print("==================================================================")
	quit(0)
