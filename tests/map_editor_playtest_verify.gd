extends SceneTree
## Verifica que Probar mapa abre WorldTest con el heightfield guardado.
##   godot --headless --path . -s tests/map_editor_playtest_verify.gd

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

	editor._on_test_pressed()
	for _frame in 20:
		await process_frame

	var world := root.get_node_or_null("WorldTest")
	if world == null:
		print("[playtest_verify] FALLO: Probar mapa no abrio WorldTest")
		quit(1)
		return
	var chunk_manager: Node3D = world.get_node("ChunkManager")
	var terrain_chunk := chunk_manager.get_node_or_null("TerrainChunk_0_0") as MeshInstance3D
	if terrain_chunk == null or not terrain_chunk.mesh is ArrayMesh:
		print("[playtest_verify] FALLO: WorldTest no recibio el terreno del editor")
		quit(1)
		return
	if chunk_manager.get_node_or_null("TerrainChunk_1_1") == null:
		print("[playtest_verify] FALLO: WorldTest no cargo el mapa grande completo")
		quit(1)
		return

	print("[playtest_verify] OK: Probar mapa abre WorldTest con el chunk editable")
	quit(0)
