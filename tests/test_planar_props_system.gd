@tool
extends SceneTree

const PlanarPropsManagerScript = preload("res://world/furniture/planar_props_manager.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")

func _init() -> void:
	print("============================================================")
	print("PRUEBA UNITARIA: SISTEMA UNIVERSAL DE PLANOS 2D (ATLAS INTELIGENTE)")
	print("============================================================")

	# 1. Inicialización
	PlanarPropsManagerScript.ensure_initialized()
	var keys := PlanarPropsManagerScript.get_all_keys()
	print("[1] Claves cargadas en el Atlas Inteligente de Planos: %d" % keys.size())
	assert(keys.size() >= 20, "Deben haberse cargado al menos las 20 alfombras iniciales")

	# 2. Validar consulta semántica de props y layers
	for i in range(mini(keys.size(), 5)):
		var key := keys[i]
		var prop := PlanarPropsManagerScript.get_prop(key)
		var layer := PlanarPropsManagerScript.get_layer_index(key)
		print("  - Prop '%s': Nombre='%s', Tipo='%s', Tamaño=%s, Capa=%d" % [
			key, prop.get("name"), prop.get("type"), prop.get("size"), layer
		])
		assert(layer >= 0, "El layer index debe ser válido (>= 0)")

	# 3. Validar filtros semánticos por superficie y tags
	var rugs_floor := PlanarPropsManagerScript.get_props_by_filter("floor", ["rug"])
	print("[2] Alfombras filtradas por ['floor', 'rug']: %d" % rugs_floor.size())
	assert(rugs_floor.size() >= 20, "Deben encontrarse al menos 20 alfombras con tag 'rug'")

	var random_bed_rug := PlanarPropsManagerScript.get_random_prop_id("floor", ["bedroom"], 12345)
	print("[3] Selección aleatoria determinista para recámara: '%s'" % random_bed_rug)
	assert(not random_bed_rug.is_empty(), "La selección aleatoria no debe ser vacía")

	# 4. Validar Material y Texture2DArray
	var mat := PlanarPropsManagerScript.get_material()
	assert(mat != null, "El ShaderMaterial compartido debe existir")
	var tex_arr = mat.get_shader_parameter("planar_textures")
	assert(tex_arr is Texture2DArray, "El parámetro planar_textures debe ser Texture2DArray")
	print("[4] Texture2DArray validado con éxito: %d capas compiladas." % tex_arr.get_layers())
	assert(tex_arr.get_layers() == keys.size(), "El número de capas en GPU debe igualar al número de props")

	# 5. Prueba de GPU Instancing en FurnitureMultiMeshSystem
	print("[5] Probando instanciación en FurnitureMultiMeshSystem...")
	var mm_sys := FurnitureMultiMeshSystemScript.new()

	# Agregar 5 alfombras de suelo
	for i in range(5):
		var t := Transform3D(Basis.IDENTITY, Vector3(float(i) * 2.0, 0.0, 0.0))
		mm_sys.add_planar_floor_prop(t, keys[i])

	mm_sys.build(false)

	var rugs_node: MultiMeshInstance3D = mm_sys.get_node_or_null("RugsMultiMesh") as MultiMeshInstance3D
	assert(rugs_node != null, "RugsMultiMesh debe haberse creado")
	assert(rugs_node.multimesh.instance_count == 5, "Debe tener 5 instancias")
	print("  ✓ RugsMultiMesh creado con 5 instancias en 1 solo Draw Call.")

	# 6. Prueba de registro dinámico en caliente (Prop #21)
	print("[6] Probando registro en caliente de un nuevo prop 2D (Alfombra #21)...")
	var initial_layers: int = int(tex_arr.get_layers())
	PlanarPropsManagerScript.register_prop("custom_rug_user_mod", {
		"name": "Alfombra Personalizada Usuario",
		"type": "floor",
		"texture": "res://assets/textures/furniture/rugs/rug_00.png",
		"size": [2.0, 1.5],
		"tags": ["floor", "rug", "custom", "bedroom"]
	}, true)

	var new_mat := PlanarPropsManagerScript.get_material()
	var new_tex_arr: Texture2DArray = new_mat.get_shader_parameter("planar_textures")
	print("  ✓ Capas antes: %d | Capas después de registro en caliente: %d" % [initial_layers, new_tex_arr.get_layers()])
	assert(new_tex_arr.get_layers() == initial_layers + 1, "Debe haberse añadido la capa 21 al Texture2DArray en caliente")
	assert(PlanarPropsManagerScript.get_prop("custom_rug_user_mod")["name"] == "Alfombra Personalizada Usuario")
	print("  ✓ Prop registrado y consultable con éxito.")

	print("\n>>> ¡TODAS LAS PRUEBAS DEL SISTEMA UNIVERSAL PASARON EXITOSAMENTE! <<<")
	quit(0)
