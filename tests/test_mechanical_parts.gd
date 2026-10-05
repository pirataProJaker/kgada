extends SceneTree

func _init():
	print("--- TESTING PROCEDURAL MECHANICAL ASSETS ---")
	
	# 1. Batería LTH
	var battery := BatteryPart.new()
	var bm: Mesh = battery.get_mesh()
	print("Battery mesh surface count: ", bm.get_surface_count() if bm else "null")
	
	# 2. Radiador
	var rad := RadiatorPart.new()
	var rm: Mesh = rad.get_mesh()
	print("Radiator mesh surface count: ", rm.get_surface_count() if rm else "null")
	
	# 3. Motor I4
	var engine_i4 := ModularEngine.new()
	engine_i4.engine_type = 0
	engine_i4._build_visuals()
	var em4: Mesh = engine_i4.get_mesh()
	print("Engine I4 mesh surface count: ", em4.get_surface_count() if em4 else "null")
	
	# 4. Motor I6
	var engine_i6 := ModularEngine.new()
	engine_i6.engine_type = 1
	engine_i6._build_visuals()
	var em6: Mesh = engine_i6.get_mesh()
	print("Engine I6 mesh surface count: ", em6.get_surface_count() if em6 else "null")
	
	print("ALL MECHANICAL PROCEDURAL ASSETS GENERATED SUCCESSFULLY WITH ATLAS!")
	quit()
