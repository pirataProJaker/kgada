@tool
extends SceneTree

func _init() -> void:
	var path = "res://PSX_Forest_AssetCollection_byStarkCrafts.fbx"
	var scene: PackedScene = load(path)
	var inst = scene.instantiate()
	var grass_node: MeshInstance3D = null
	for c in inst.get_children():
		if c.name == "PSX_Grass":
			grass_node = c
			break
			
	if grass_node:
		print("--- DETALLES DE PSX_Grass ---")
		print("Transform local: ", grass_node.transform)
		print("AABB local de mesh: ", grass_node.mesh.get_aabb())
		var mat = grass_node.get_surface_override_material(0)
		if not mat and grass_node.mesh.get_surface_count() > 0:
			mat = grass_node.mesh.surface_get_material(0)
		print("Material: ", mat)
		if mat is BaseMaterial3D:
			print("Albedo color: ", mat.albedo_color)
			print("Albedo texture: ", mat.albedo_texture)
			print("Transparency: ", mat.transparency)
			print("Cull mode: ", mat.cull_mode)
		
		# Vértices
		var arrays = grass_node.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		print("Vértices count: ", verts.size())
		for i in range(verts.size()):
			print(" V%d: %s | UV: %s" % [i, verts[i], uvs[i] if uvs.size() > i else "N/A"])
			
	inst.free()
	quit(0)
