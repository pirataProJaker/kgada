extends SceneTree

func _init() -> void:
	var ProceduralFlower = load("res://world/procedural_flora/procedural_flower.gd")
	var shrub = ProceduralFlower.new()
	shrub.profile_id = "shrub_rose"
	shrub.flower_seed = 12345
	
	var t0 = Time.get_ticks_usec()
	shrub.generate()
	var t1 = Time.get_ticks_usec()
	print("SHRUB generate() time: %.2f ms" % ((t1 - t0) / 1000.0))
	
	var m = shrub.get_mesh()
	var t_hud_start = Time.get_ticks_usec()
	for i in range(60):
		for s in range(m.get_surface_count()):
			var arrays = m.surface_get_arrays(s)
			var v = arrays[Mesh.ARRAY_VERTEX].size()
	var t_hud_end = Time.get_ticks_usec()
	print("60 frames of surface_get_arrays: %.2f ms total (%.2f ms per frame!)" % [
		(t_hud_end - t_hud_start) / 1000.0,
		(t_hud_end - t_hud_start) / 1000.0 / 60.0
	])
	quit(0)
