@tool
extends SceneTree

func _init() -> void:
	print("=== INICIANDO CAPTURA DE ESCAPARATE DE MOBILIARIO DE OFICINA ===")

	var scene := load("res://scenes/office_pack_showcase.tscn")
	if scene == null:
		printerr("ERROR: No se pudo cargar res://scenes/office_pack_showcase.tscn")
		quit(1)
		return

	var root_node = scene.instantiate()
	root.add_child(root_node)

	# Esperar frames para inicialización de GPU y nodos autoload
	for i in range(12):
		await process_frame

	# Eliminar completamente todos los CanvasLayers y overlays de UI para obtener una captura de estudio pura
	for child in root.get_children():
		if child != root_node:
			root.remove_child(child)
			child.queue_free()

	for i in range(4):
		await process_frame

	var engine: ObjectEngine = root_node.get_node_or_null("ShowcaseObjectEngine")
	if engine == null:
		printerr("ERROR: No se encontró ShowcaseObjectEngine")
		quit(1)
		return

	var stats := engine.get_stats()
	print("=======================================================================")
	print("✓ TELEMETRÍA CONFIRMADA DE OFFICE PACK:")
	print("- Total Piezas Geométricas: %d" % stats["total_instances"])
	print("- DRAW CALLS TOTALES PARA LA COLECCIÓN COMPLETA: %d" % stats["draw_calls"])
	print("- Primitivas en Hardware Instancing: %s" % str(stats["primitives_active"]))
	print("- Formas de Colisión Físicas: %d" % stats["collision_shapes"])
	print("=======================================================================")

	# 1. Capturar vista general completa de la cuadrícula 4x3
	var vp := root.get_viewport()
	var cam: Camera3D = root_node.get_node_or_null("ShowcaseCamera")
	if cam:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 7.2
		cam.global_position = Vector3(-0.15, 4.12, 6.62)
		cam.rotation_degrees = Vector3(-28.0, 0.0, 0.0)

	for i in range(6):
		await process_frame

	var img := vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_office_pack.png")
		print("✓ Captura general guardada en res://tests/showcase_office_pack.png")

	if cam:
		# 2. Captura de Fila 1: Escritorios (primer plano fila completa)
		cam.size = 4.3
		cam.global_position = Vector3(-0.15, 3.26, 2.98)
		for i in range(6):
			await process_frame
		var img_desks := vp.get_texture().get_image()
		if img_desks:
			img_desks.save_png("res://tests/showcase_office_desks.png")
			print("✓ Captura de escritorios guardada en res://tests/showcase_office_desks.png")

		# 3. Captura de Fila 2: Sillas y Archiveros (primer plano fila completa)
		cam.size = 4.3
		cam.global_position = Vector3(-0.15, 4.02, 6.62)
		for i in range(6):
			await process_frame
		var img_chairs := vp.get_texture().get_image()
		if img_chairs:
			img_chairs.save_png("res://tests/showcase_office_chairs_cabinets.png")
			print("✓ Captura de sillas y archiveros guardada en res://tests/showcase_office_chairs_cabinets.png")

		# 4. Captura de Fila 3: Armarios y Libreros (primer plano fila completa)
		cam.size = 4.3
		cam.global_position = Vector3(-0.15, 4.88, 10.26)
		for i in range(6):
			await process_frame
		var img_storage := vp.get_texture().get_image()
		if img_storage:
			img_storage.save_png("res://tests/showcase_office_storage.png")
			print("✓ Captura de libreros y armarios guardada en res://tests/showcase_office_storage.png")

	print("=== CAPTURA FINALIZADA EXITOSAMENTE ===")
	quit(0)
