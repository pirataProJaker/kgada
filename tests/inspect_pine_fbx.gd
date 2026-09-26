@tool
extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("=== INSPECCIÓN DE ÁRBOLES / PINOS FBX ===")
	print("==================================================================")
	
	# 1. PSX_Forest_AssetCollection_byStarkCrafts.fbx (Carpeta raíz)
	var root_fbx_path := "res://PSX_Forest_AssetCollection_byStarkCrafts.fbx"
	if ResourceLoader.exists(root_fbx_path):
		print("\n[1] Archivo en raíz: %s" % root_fbx_path)
		var scene: PackedScene = load(root_fbx_path)
		if scene:
			var inst: Node = scene.instantiate()
			for child in inst.get_children():
				if child is MeshInstance3D and ("Tree" in child.name or "Pine" in child.name):
					_inspect_mesh_node(child)
			inst.free()
			
	# 2. Tree Pack 1.1
	print("\n[2] Archivos en assets/tree_pack_1.1/tree_pack_1.1/models/")
	for i in [1, 2, 3, 4, 10, 20, 30, 36]:
		var p = "res://assets/tree_pack_1.1/tree_pack_1.1/models/tree%02d.fbx" % i
		if ResourceLoader.exists(p):
			var scene: PackedScene = load(p)
			if scene:
				var inst: Node = scene.instantiate()
				for child in inst.get_children():
					if child is MeshInstance3D:
						_inspect_mesh_node(child, "tree%02d.fbx" % i)
				inst.free()
				
	print("\n==================================================================")
	quit(0)

func _inspect_mesh_node(mi: MeshInstance3D, label_prefix: String = "") -> void:
	var m: Mesh = mi.mesh
	if not m:
		return
		
	var aabb: AABB = m.get_aabb()
	var total_tris := 0
	var total_verts := 0
	var materials: Array[String] = []
	
	for s in range(m.get_surface_count()):
		var arr = m.surface_get_arrays(s)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			total_verts += arr[Mesh.ARRAY_VERTEX].size()
		if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
			total_tris += arr[Mesh.ARRAY_INDEX].size() / 3
		elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			total_tris += arr[Mesh.ARRAY_VERTEX].size() / 3
			
		var mat = mi.get_surface_override_material(s)
		if mat == null:
			mat = m.surface_get_material(s)
		if mat:
			var tex_name = "sin_textura"
			if mat is StandardMaterial3D and mat.albedo_texture:
				tex_name = mat.albedo_texture.resource_path.get_file()
			materials.append("%s (albedo: %s)" % [mat.resource_name if mat.resource_name != "" else mat.get_class(), tex_name])
		else:
			materials.append("null")
			
	var name_str = ("[%s] %s" % [label_prefix, mi.name]) if label_prefix != "" else mi.name
	print(" -> %s:" % name_str)
	print("    • Triángulos: %d | Vértices: %d | Superficies: %d" % [total_tris, total_verts, m.get_surface_count()])
	print("    • Dimensiones AABB: %.2fm ancho x %.2fm alto x %.2fm fondo (Centro local: %s)" % [aabb.size.x, aabb.size.y, aabb.size.z, str(aabb.get_center())])
	print("    • Materiales: %s" % str(materials))
