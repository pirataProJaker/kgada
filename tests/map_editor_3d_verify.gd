extends SceneTree
## Comprueba que el editor nuevo usa el mundo real de Marching Cubes.
##   godot --headless --path . -s tests/map_editor_3d_verify.gd

const EDITOR_SCENE := preload("res://map_editor/map_editor.tscn")


func _initialize() -> void:
	var editor := EDITOR_SCENE.instantiate()
	root.add_child(editor)
	for _frame in 8:
		await process_frame
	editor.map_size_option.select(1)
	editor._on_new_pressed()
	for _frame in 8:
		await process_frame

	var document = editor.document
	var chunk_manager: Node3D = editor.get_node("Terrain/ChunkManager")
	var terrain_chunk := chunk_manager.get_node_or_null("TerrainChunk_0_0") as MeshInstance3D
	var camera: Camera3D = editor.get_node("Camera3D")
	if document.terrain_mode != "flat":
		print("[3d_verify] FALLO: el mapa nuevo no esta marcado como flat")
		quit(1)
		return
	if document.grid_size != Vector2i(65, 65) or not is_equal_approx(float(document.cell_size), 2.5):
		print("[3d_verify] FALLO: el documento no esta alineado con el chunk real")
		quit(1)
		return
	if editor.get_node_or_null("Terrain/TerrainCubes") != null or terrain_chunk == null:
		print("[3d_verify] FALLO: no se encontro el chunk real o quedo la maqueta")
		quit(1)
		return
	if chunk_manager.get_node_or_null("TerrainChunk_1_1") == null:
		print("[3d_verify] FALLO: el mapa grande no genero sus cuatro chunks")
		quit(1)
		return
	if not terrain_chunk.mesh is ArrayMesh or terrain_chunk.mesh.get_surface_count() != 1:
		print("[3d_verify] FALLO: el terreno no es una ArrayMesh real")
		quit(1)
		return
	var terrain_material := terrain_chunk.material_override as ShaderMaterial
	if terrain_material == null or terrain_material.shader == null or terrain_material.shader.resource_path != "res://shaders/psx_vertex_snap.gdshader":
		print("[3d_verify] FALLO: el chunk no usa el shader del mundo")
		quit(1)
		return
	if terrain_chunk.find_child("CollisionShape3D", true, false) == null:
		print("[3d_verify] FALLO: el chunk real no tiene colision trimesh")
		quit(1)
		return
	if camera.projection != Camera3D.PROJECTION_PERSPECTIVE or camera.global_position.y <= 0.0:
		print("[3d_verify] FALLO: camara 3D superior no configurada")
		quit(1)
		return

	document.set_height(Vector2i(10, 10), 15.0)
	editor.map_size_option.select(2)
	editor._on_resize_pressed()
	for _frame in 12:
		await process_frame
	document = editor.document
	if document.grid_size != Vector2i(97, 97) or not is_equal_approx(float(document.get_height(Vector2i(10, 10))), 15.0):
		print("[3d_verify] FALLO: redimensionar no conserva las alturas existentes")
		quit(1)
		return
	if chunk_manager.get_node_or_null("TerrainChunk_2_2") == null:
		print("[3d_verify] FALLO: el nuevo tamaño no genero el chunk adicional")
		quit(1)
		return
	terrain_chunk = chunk_manager.get_node_or_null("TerrainChunk_0_0") as MeshInstance3D

	var original_neighbor_height: float = float(document.get_height(Vector2i(15, 16)))
	editor._set_tool("raise")
	editor._apply_height_brush(Vector2i(16, 16))
	var raised_height: float = float(document.get_height(Vector2i(16, 16)))
	var neighbor_height: float = float(document.get_height(Vector2i(15, 16)))
	if not is_equal_approx(raised_height, 12.5) or neighbor_height <= original_neighbor_height or neighbor_height >= raised_height:
		print("[3d_verify] FALLO: el pincel no modifica vecinos con suavizado")
		quit(1)
		return
	for _frame in 4:
		await process_frame
	terrain_chunk = chunk_manager.get_node_or_null("TerrainChunk_0_0") as MeshInstance3D
	if terrain_chunk == null or not terrain_chunk.mesh is ArrayMesh:
		print("[3d_verify] FALLO: el chunk real no se regenero despues del pincel")
		quit(1)
		return
	var terrain_chunk_count := _count_nodes_with_prefix(chunk_manager, "TerrainChunk_")
	var grid_chunk_count := _count_nodes_with_prefix(editor.get_node("EditorOverlay/EditGrid"), "GridChunk_")
	if terrain_chunk_count != 36 or grid_chunk_count != 36:
		print("[3d_verify] FALLO: una edicion acumulo mallas (%d terreno, %d rejilla)" % [terrain_chunk_count, grid_chunk_count])
		quit(1)
		return

	print("[3d_verify] OK: editor usa TerrainChunk_0_0 con Marching Cubes, shader PSX y pincel natural")
	quit(0)


func _count_nodes_with_prefix(parent: Node, prefix: String) -> int:
	var count := 0
	for child in parent.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count
