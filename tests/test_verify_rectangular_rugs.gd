@tool
extends SceneTree

const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const HouseFurniturePlannerScript = preload("res://world/furniture/house_furniture_planner.gd")

func _init() -> void:
	print("============================================================")
	print("VERIFICACIÓN DE ALFOMBRAS RECTANGULARES Y GPU INSTANCING")
	print("============================================================")

	var mm_sys := FurnitureMultiMeshSystemScript.new()

	# 1. Probar registro de varias alfombras con diferentes IDs (0 a 19)
	for i in range(20):
		var pos := Vector3(float(i % 5) * 2.2, 0.0, float(i / 5) * 1.8)
		var t := Transform3D(Basis.IDENTITY, pos)
		mm_sys.add_rug_rectangular(t, i)

	print("Total de alfombras registradas: ", mm_sys._rugs.size())
	assert(mm_sys._rugs.size() == 20, "Deben haber 20 alfombras registradas")

	# 2. Compilar el sistema MultiMesh
	mm_sys.build(false)

	# 3. Validar el nodo RugsMultiMesh
	var rugs_node: MultiMeshInstance3D = mm_sys.get_node_or_null("RugsMultiMesh") as MultiMeshInstance3D
	if rugs_node == null:
		printerr("ERROR: RugsMultiMesh no fue creado en FurnitureMultiMeshSystem!")
		quit(1)
		return

	print("✓ RugsMultiMesh creado exitosamente.")
	var mm: MultiMesh = rugs_node.multimesh
	print("✓ MultiMesh instance count: %d (esperado 20)" % mm.instance_count)
	assert(mm.instance_count == 20, "MultiMesh instance count mismatch")
	print("✓ MultiMesh use_colors: ", mm.use_colors)
	assert(mm.use_colors == true, "MultiMesh debe tener use_colors activo")

	# Validar que los registros tengan sus prop_ids correctos
	for i in range(20):
		var entry = mm_sys._rugs[i]
		var prop_id: String = str(entry.get("prop_id", ""))
		print("  - Instancia %d: prop_id = %s -> Nombre: %s" % [
			i, prop_id, FurnitureTextureManagerScript.get_rug_name(i)
		])
		assert(prop_id == "rug_%02d" % i, "El ID de alfombra registrado debe coincidir")

	# 4. Validar el material y shader
	var mat: ShaderMaterial = rugs_node.material_override as ShaderMaterial
	if mat == null:
		printerr("ERROR: El material_override de RugsMultiMesh no es ShaderMaterial!")
		quit(1)
		return

	print("✓ Material Shader configurado correctamente: ", mat.shader.resource_path)
	var atlas_tex = mat.get_shader_parameter("planar_textures")
	print("✓ Planar Textures Array asignado: ", atlas_tex != null)
	assert(atlas_tex != null, "planar_textures debe estar asignado en el material")

	# 5. Validar malla unitaria y escala de instancias
	var mesh: ArrayMesh = mm.mesh as ArrayMesh
	var aabb: AABB = mesh.get_aabb()
	print("✓ Malla base unitaria: Size = (W: %.3f, L: %.3f)" % [aabb.size.x, aabb.size.z])
	assert(is_equal_approx(aabb.size.x, 1.0) and is_equal_approx(aabb.size.z, 1.0), "La malla base debe ser unitaria 1x1")

	print("\n>>> ¡TODAS LAS VALIDACIONES PASARON EXITOSAMENTE! <<<")
	quit(0)
