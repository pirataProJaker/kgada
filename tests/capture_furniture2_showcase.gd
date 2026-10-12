@tool
extends SceneTree

func _init() -> void:
	print("=== INICIANDO CAPTURA DE ESCAPARATE DE FURNITURE 2.0 ===")

	var scene := load("res://scenes/furniture2_showcase.tscn")
	if scene == null:
		printerr("ERROR: No se pudo cargar res://scenes/furniture2_showcase.tscn")
		quit(1)
		return

	var root_node = scene.instantiate()
	root.add_child(root_node)

	# Esperar frames para inicialización de GPU
	for i in range(12):
		await process_frame

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
	print("✓ TELEMETRÍA CONFIRMADA DE FURNITURE 2.0:")
	print("- Total Piezas Geométricas Instanciadas: %d" % stats["total_instances"])
	print("- DRAW CALLS TOTALES EN ESCENA: %d" % stats["draw_calls"])
	print("- Primitivas en Hardware Instancing: %s" % str(stats["primitives_active"]))
	print("=======================================================================")

	var vp := root.get_viewport()
	var cam: Camera3D = root_node.get_node_or_null("ShowcaseCamera")
	if cam == null:
		cam = Camera3D.new()
		root_node.add_child(cam)

	# 1. Captura General (81 modelos)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 65.0
	cam.global_position = Vector3(0.0, 16.0, 24.0)
	cam.look_at(Vector3(0.0, 1.0, 9.0), Vector3.UP)

	for i in range(6):
		await process_frame

	var img := vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_furniture2_overall.png")
		print("✓ Captura general guardada en res://tests/showcase_furniture2_overall.png")

	# 2. Captura Detallada: Asientos y Sofás (Panorámica completa de 12 modelos)
	cam.fov = 72.0
	cam.global_position = Vector3(0.0, 4.8, 13.5)
	cam.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_furniture2_seating.png")
		print("✓ Captura general de asientos guardada en res://tests/showcase_furniture2_seating.png")

	# 2a. Primer plano: Los 4 Sofás (Damask Gold, Floral Cottage, Wood Minimal, Chesterfield Red)
	cam.fov = 64.0
	cam.global_position = Vector3(-8.7, 1.8, 4.4)
	cam.look_at(Vector3(-8.7, 0.55, 0.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_seating_sofas.png")
		print("✓ Primer plano de sofás guardado en res://tests/showcase_seating_sofas.png")

	# 2b. Primer plano: Los 5 Sillones individuales (Chesterfield, Wingback, Charcoal, SkyBlue, Mustard)
	cam.fov = 68.0
	cam.global_position = Vector3(1.2, 1.8, 4.4)
	cam.look_at(Vector3(1.2, 0.55, 0.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_seating_armchairs.png")
		print("✓ Primer plano de sillones guardado en res://tests/showcase_seating_armchairs.png")

	# 2c. Primer plano: Las 3 Sillas de acento (Dining Cream, Baroque Oval, Louis XV Blue)
	cam.fov = 48.0
	cam.global_position = Vector3(10.0, 1.6, 3.2)
	cam.look_at(Vector3(10.0, 0.55, 0.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_seating_chairs.png")
		print("✓ Primer plano de sillas guardado en res://tests/showcase_seating_chairs.png")

	# 3. Captura Detallada: Camas
	cam.global_position = Vector3(0.0, 3.5, 9.5)
	cam.look_at(Vector3(0.0, 0.8, 4.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_furniture2_beds.png")
		print("✓ Captura de camas guardada en res://tests/showcase_furniture2_beds.png")

	# 4. Captura Detallada: Almacenamiento
	cam.global_position = Vector3(0.0, 4.2, 14.5)
	cam.look_at(Vector3(0.0, 1.2, 8.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_furniture2_storage.png")
		print("✓ Captura de almacenamiento guardada en res://tests/showcase_furniture2_storage.png")

	# 5. Captura Detallada: Cocina y Comedor
	cam.global_position = Vector3(0.0, 3.8, 17.5)
	cam.look_at(Vector3(0.0, 1.0, 12.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_furniture2_kitchen.png")
		print("✓ Captura de cocina guardada en res://tests/showcase_furniture2_kitchen.png")

	# 6. Captura Detallada: Props, Radios, Luces y Comida
	cam.global_position = Vector3(0.0, 3.5, 22.0)
	cam.look_at(Vector3(0.0, 0.6, 17.0), Vector3.UP)
	for i in range(6):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_furniture2_props.png")
		print("✓ Captura de props guardada en res://tests/showcase_furniture2_props.png")

	print("=== TODAS LAS CAPTURAS DE FURNITURE 2.0 GUARDADAS EXITOSAMENTE ===")
	quit(0)
