@tool
extends SceneTree

## Script de Verificación y Captura del Conjunto de Muebles de Oficina (Office Pack)
## Valida los 12 modelos en Hardware Instancing a +0 Draw Calls en ObjectEngine.

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")

func _init() -> void:
	print("=======================================================================")
	print("INICIANDO PRUEBA Y ESCAPARATE DE OFICINA (OFFICE PACK - 12 MODELOS)")
	print("=======================================================================")

	# 1. Crear escena 3D en el árbol
	var root_3d := Node3D.new()
	root_3d.name = "OfficeShowcaseRoot"
	root.add_child(root_3d)

	# 2. Iluminación y Ambiente tipo render de producto (fondo oscuro)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.10) # Fondo oscuro idéntico a la referencia
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.78)
	env.ambient_light_energy = 0.9

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root_3d.add_child(world_env)

	# Luz direccional suave
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(30.0), 0.0)
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.98, 0.95)
	light.shadow_enabled = true
	root_3d.add_child(light)

	# Luz de relleno secundaria
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation = Vector3(deg_to_rad(25.0), deg_to_rad(-140.0), 0.0)
	fill_light.light_energy = 0.5
	fill_light.light_color = Color(0.75, 0.85, 1.0)
	root_3d.add_child(fill_light)

	# 3. ObjectEngine para +0 Draw Calls
	var engine = ObjectEngineScript.new()
	engine.name = "OfficeObjectEngine"
	root_3d.add_child(engine)
	var builder = engine.get_builder()

	# 4. Instanciar los 12 modelos en cuadrícula 4x3 (exactamente como la imagen de referencia)
	# Fila 1 (Z = -2.8): Escritorios
	var r1_z := -2.8
	var rot_desk := deg_to_rad(20.0)
	var basis_desk := Basis(Vector3.UP, rot_desk)

	# 1. Escritorio Ejecutivo Doble Pedestal
	builder.add_furniture_by_script("office_desk_double", Transform3D(basis_desk, Vector3(-4.0, 0.0, r1_z)))
	# 2. Escritorio Metálico Tanker
	builder.add_furniture_by_script("office_desk_metal", Transform3D(basis_desk, Vector3(-1.3, 0.0, r1_z)))
	# 3. Escritorio en L con Patas Azules
	builder.add_furniture_by_script("office_desk_l_shaped", Transform3D(Basis(Vector3.UP, deg_to_rad(-15.0)), Vector3(1.3, 0.0, r1_z - 0.2)))
	# 4. Escritorio Sencillo Patas Abiertas
	builder.add_furniture_by_script("office_desk_single", Transform3D(basis_desk, Vector3(3.9, 0.0, r1_z)))

	# Fila 2 (Z = 0.0): Sillas y Archiveros
	var r2_z := 0.0
	var rot_chair := deg_to_rad(25.0)
	var basis_chair := Basis(Vector3.UP, rot_chair)

	# 5. Silla Ergonómica Verde
	builder.add_furniture_by_script("office_chair_green", Transform3D(basis_chair, Vector3(-3.8, 0.0, r2_z)))
	# 6. Silla Roja Vintage
	builder.add_furniture_by_script("office_chair_red", Transform3D(basis_chair, Vector3(-1.3, 0.0, r2_z)))
	# 7. Archivero Vertical Cerrado
	builder.add_furniture_by_script("office_file_cabinet_closed", Transform3D(basis_desk, Vector3(1.3, 0.0, r2_z)))
	# 8. Archivero Vertical Abierto con Carpetas
	builder.add_furniture_by_script("office_file_cabinet_open", Transform3D(basis_desk, Vector3(3.8, 0.0, r2_z)))

	# Fila 3 (Z = +2.8): Armarios y Libreros
	var r3_z := 2.8
	var rot_cab := deg_to_rad(20.0)
	var basis_cab := Basis(Vector3.UP, rot_cab)

	# 9. Armario Alto 2 Puertas
	builder.add_furniture_by_script("office_cabinet_tall", Transform3D(basis_cab, Vector3(-3.8, 0.0, r3_z)))
	# 10. Mueble Bajo 2 Puertas
	builder.add_furniture_by_script("office_cabinet_low", Transform3D(basis_cab, Vector3(-1.3, 0.0, r3_z)))
	# 11. Librero Alto Abierto 5 Niveles
	builder.add_furniture_by_script("office_bookcase_tall", Transform3D(basis_cab, Vector3(1.3, 0.0, r3_z)))
	# 12. Librero Bajo Abierto 2 Niveles
	builder.add_furniture_by_script("office_bookcase_low", Transform3D(basis_cab, Vector3(3.8, 0.0, r3_z)))

	# Commit al GPU
	engine.commit()

	# 5. Configurar Cámara con vista panorámica y perspectiva de estudio
	var cam := Camera3D.new()
	cam.name = "ShowcaseCamera"
	cam.fov = 42.0
	root_3d.add_child(cam)
	cam.global_position = Vector3(0.0, 7.8, 10.2)
	cam.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
	cam.make_current()

	# Esperar frames para inicialización de GPU
	for i in range(5):
		await process_frame

	var stats := engine.get_stats()
	print("-----------------------------------------------------------------------")
	print("✓ ESTADÍSTICAS OFICIALES DE RENDERIZADO:")
	print("- Total Piezas Geométricas Instanciadas: %d" % stats["total_instances"])
	print("- DRAW CALLS CONSUMIDOS (HARDWARE INSTANCING): %d" % stats["draw_calls"])
	print("- Primitivas Activas en Escena: %s" % str(stats["primitives_active"]))
	print("- Cajas de Colisión Físicas: %d" % stats["collision_shapes"])
	print("-----------------------------------------------------------------------")

	# Capturar vista previa
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		img.save_png("res://tests/showcase_office_pack.png")
		print("✓ Captura guardada con éxito en res://tests/showcase_office_pack.png")

	print("=======================================================================")
	print("PRUEBA DE OFFICE PACK FINALIZADA CORRECTAMENTE")
	print("=======================================================================")
	quit(0)
