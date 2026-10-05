@tool
extends SceneTree

func _init() -> void:
	var glb_path := "res://assets/models/vehicles/sedan_80s/sedan_modular.glb"
	var scene: PackedScene = load(glb_path)
	var f := FileAccess.open("res://glb_hierarchy.txt", FileAccess.WRITE)
	if not scene:
		if f: f.store_line("ERROR: Failed to load GLB: " + glb_path)
		quit(1)
		return
	var inst := scene.instantiate()
	if f: f.store_line("--- GLB HIERARCHY ---")
	_print_tree(inst, 0, f)
	if f: f.close()
	quit(0)

func _print_tree(n: Node, depth: int, f: FileAccess) -> void:
	var ind := "  ".repeat(depth)
	var pos_str := ""
	if n is Node3D:
		pos_str = "Pos: " + str((n as Node3D).position) + " Rot: " + str((n as Node3D).rotation_degrees)
	var line := "%s- %s (%s) %s" % [ind, n.name, n.get_class(), pos_str]
	if f: f.store_line(line)
	for c in n.get_children():
		_print_tree(c, depth + 1, f)

