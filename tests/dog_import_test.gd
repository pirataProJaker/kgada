extends SceneTree
## Prueba de importacion de los modelos del perro (assets/Dog/).
## Se ejecuta con:
##   godot --headless --path . -s tests/dog_import_test.gd
## Extiende SceneTree para que funcione con -s sin necesidad de escena.

func _initialize() -> void:
	_test("res://assets/Dog/DogFBX.fbx", "FBX")
	_test("res://assets/Dog/DogGlb.glb", "GLB")
	_test("res://assets/cat/cat.fbx", "CAT (referencia)")
	print("[dog_import_test] FIN")
	quit()


func _test(path: String, label: String) -> void:
	print("=== Probando %s (%s) ===" % [label, path])
	if not ResourceLoader.exists(path):
		print("  [FALLO] ResourceLoader.exists() = false")
		return
	var res: Resource = load(path)
	if res == null:
		print("  [FALLO] load() devolvio null")
		return
	print("  [OK] load() -> %s" % res.get_class())
	if res is PackedScene:
		var inst: Node = res.instantiate()
		if inst is Node3D:
			var aabb := _combined_aabb(inst as Node3D)
			print("  [OK] instancia Node3D, AABB combinado = %s" % aabb)
			print("  [OK] tamano AABB = %s" % aabb.size)
			_apply_material(inst)
			_force_visible(inst)
		else:
			print("  [AVISO] raiz no es Node3D, es %s" % inst.get_class())
		inst.free()
	else:
		print("  [AVISO] no es PackedScene, es %s" % res.get_class())


static func _combined_aabb(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for vi in _find_visual(model):
		var local_aabb: AABB = vi.get_aabb()
		if first:
			result = local_aabb
			first = false
		else:
			result = result.merge(local_aabb)
	return result


static func _find_visual(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual(child)
	return found


static func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		var mesh: Mesh = mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				mi.set_surface_override_material(i, _build_material())
	for child in node.get_children():
		_apply_material(child)


static func _build_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _force_visible(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_force_visible(child)
