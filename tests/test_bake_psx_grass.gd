@tool
extends SceneTree

const ForestModelUtils = preload("res://world/forest_model_utils.gd")

func _init() -> void:
	print("--- TEST DE HORNEADO DE PSX_Grass ---")
	var utils = ForestModelUtils.new()
	var grass_node = utils.get_model(ForestModelUtils.MODEL_GRASS, 0.45)
	if not grass_node:
		print("Error: No se pudo obtener PSX_Grass")
		quit(1)
		return
	
	var mi: MeshInstance3D = grass_node.get_child(0) as MeshInstance3D
	var src_mesh: Mesh = mi.mesh
	var xform: Transform3D = Transform3D().translated(grass_node.position).scaled(grass_node.scale) * mi.transform
	
	# Hornear en nuevo ArrayMesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var arrays = src_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	
	var mat = mi.get_surface_override_material(0)
	if not mat and src_mesh.get_surface_count() > 0:
		mat = src_mesh.surface_get_material(0)
	
	for i in range(indices.size()):
		var idx = indices[i]
		var v = xform * verts[idx]
		var uv = uvs[idx] if uvs.size() > idx else Vector2.ZERO
		var n = (xform.basis * normals[idx]).normalized() if normals.size() > idx else Vector3.UP
		
		st.set_normal(n)
		st.set_uv(uv)
		st.add_vertex(v)
		
	var baked_mesh = st.commit()
	baked_mesh.surface_set_material(0, mat)
	
	print("Mesh horneado con éxito:")
	print(" - Triángulos: ", indices.size() / 3)
	print(" - AABB: ", baked_mesh.get_aabb())
	print(" - Material: ", mat)
	
	grass_node.free()
	quit(0)
