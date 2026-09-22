@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECCIÓN DE PSX_Forest_AssetCollection_byStarkCrafts ---")
	var paths = [
		"res://PSX_Forest_AssetCollection_byStarkCrafts.fbx",
		"res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts.fbx"
	]
	
	for p in paths:
		if ResourceLoader.exists(p):
			print("\nCargando: ", p)
			var scene: PackedScene = load(p)
			if scene:
				var inst = scene.instantiate()
				print("Hijos en la escena:")
				for child in inst.get_children():
					if child is MeshInstance3D:
						var m: Mesh = child.mesh
						var tris = 0
						if m:
							for s in range(m.get_surface_count()):
								var arr = m.surface_get_arrays(s)
								if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
									tris += arr[Mesh.ARRAY_INDEX].size() / 3
								elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
									tris += arr[Mesh.ARRAY_VERTEX].size() / 3
						print(" - %s (MeshInstance3D, %d tris, mat=%s)" % [child.name, tris, child.get_surface_override_material(0) or (m.surface_get_material(0) if m and m.get_surface_count() > 0 else null)])
				inst.free()
			break
	quit(0)
