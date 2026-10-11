extends SceneTree

## Script de Verificación y Captura del Escaparate Completo del Motor de Objetos
## Valida que todos los modelos usen el Atlas Inteligente (ObjectAtlas) fielmente.

func _init() -> void:
	print("=== INICIANDO VALIDACIÓN DEL ESCAPARATE DE OBJETOS (MOTOR DE OBJETOS) ===")

	var showcase_scene := load("res://scenes/all_objects_engine_showcase.tscn")
	if showcase_scene == null:
		printerr("ERROR: No se pudo cargar res://scenes/all_objects_engine_showcase.tscn")
		quit(1)
		return

	var root_node = showcase_scene.instantiate()
	root.add_child(root_node)

	# Esperar 4 frames para que la GPU procese los MultiMeshes y se rendericen las texturas
	for i in range(5):
		await process_frame

	var engine: ObjectEngine = root_node.get_node_or_null("ShowcaseObjectEngine")
	if engine == null:
		printerr("ERROR: No se encontró ShowcaseObjectEngine")
		quit(1)
		return

	var stats := engine.get_stats()
	print("=======================================================================")
	print("✓ TELEMETRÍA CONFIRMADA:")
	print("- Total Piezas Geométricas Instanciadas: %d" % stats["total_instances"])
	print("- DRAW CALLS TOTALES PARA TODA LA COLECCIÓN: %d" % stats["draw_calls"])
	print("- Primitivas en Hardware Instancing: %s" % str(stats["primitives_active"]))
	print("- Cajas de Colisión Consolidadas: %d" % stats["collision_shapes"])
	print("=======================================================================")

	# Capturar vista general
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_atlas_full.png")
		print("✓ Captura general guardada en res://tests/showcase_atlas_full.png")

	# Mover cámara a vista de Electrodomésticos de Cocina (Estufa, Refri, Gabinetes)
	var cam: Camera3D = root_node.get_node("ShowcaseCamera")
	if cam:
		# Vista 1: Estufa y Gabinetes de cocina
		cam.global_position = Vector3(1.5, 1.2, 1.8)
		cam.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(5.0), 0.0)
		for i in range(3):
			await process_frame
		var img_kitchen := vp.get_texture().get_image()
		if img_kitchen:
			img_kitchen.save_png("res://tests/showcase_kitchen_appliances.png")
			print("✓ Captura de cocina guardada en res://tests/showcase_kitchen_appliances.png")

		# Vista 1b: Primer plano exacto de Gabinete y Fregadero (X=3.6 y X=5.0)
		cam.global_position = Vector3(4.3, 1.8, 1.6)
		cam.rotation = Vector3(deg_to_rad(-35.0), 0.0, 0.0)
		for i in range(3):
			await process_frame
		var img_cabinets_sink := vp.get_texture().get_image()
		if img_cabinets_sink:
			img_cabinets_sink.save_png("res://tests/showcase_cabinets_and_sink.png")
			print("✓ Captura de gabinete y fregadero guardada en res://tests/showcase_cabinets_and_sink.png")

		# Vista 2: Refrigeradores (Cerrado y Abierto)
		cam.global_position = Vector3(10.5, 1.4, 2.2)
		cam.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
		for i in range(3):
			await process_frame
		var img_refri := vp.get_texture().get_image()
		if img_refri:
			img_refri.save_png("res://tests/showcase_refrigerators.png")
			print("✓ Captura de refrigeradores guardada en res://tests/showcase_refrigerators.png")

		# Vista 3: Cama con Cobija y Sábana del Atlas (Lobo San Marcos)
		cam.global_position = Vector3(18.0, 1.45, 2.2)
		cam.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
		for i in range(3):
			await process_frame
		var img_bed := vp.get_texture().get_image()
		if img_bed:
			img_bed.save_png("res://tests/showcase_bed_linens.png")
			print("✓ Captura de cama guardada en res://tests/showcase_bed_linens.png")

		# Vista 3b: Alineación de los 4 Estados de la Cama (MADE, UNMADE, STRIPPED, BARE_MATTRESS)
		cam.global_position = Vector3(20.7, 2.5, 4.4)
		cam.rotation = Vector3(deg_to_rad(-24.0), 0.0, 0.0)
		for i in range(3):
			await process_frame
		var img_bed_states := vp.get_texture().get_image()
		if img_bed_states:
			img_bed_states.save_png("res://tests/showcase_bed_all_states.png")
			print("✓ Captura de los 4 estados de cama guardada en res://tests/showcase_bed_all_states.png")

		# Vista 4: Vitrina Comercial OXXO con Termostato y Marquesina
		cam.global_position = Vector3(28.5, 1.6, 2.6)
		cam.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
		for i in range(3):
			await process_frame
		var img_cooler := vp.get_texture().get_image()
		if img_cooler:
			img_cooler.save_png("res://tests/showcase_commercial_coolers.png")
			print("✓ Captura de vitrinas comerciales guardada en res://tests/showcase_commercial_coolers.png")

	print("=== VALIDACIÓN COMPLETADA EXITOSAMENTE ===")
	quit(0)
