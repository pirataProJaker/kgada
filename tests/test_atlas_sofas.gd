extends SceneTree

func _init() -> void:
	print("--- Testing Atlas Registration for sofa_fabrics_atlas ---")
	var ObjectAtlasScript = load("res://world/object_engine/object_atlas.gd")
	var r0 = ObjectAtlasScript.get_sofa_fabric_region(0)
	var r3 = ObjectAtlasScript.get_sofa_fabric_region("vintage_04_brocade_green")
	var r9 = ObjectAtlasScript.get_sofa_fabric_region("modern_02_boucle_oat")
	print("Fabric 0 (Jacquard Gold): ", r0)
	print("Fabric 3 (Brocade Green): ", r3)
	print("Fabric 9 (Modern Boucle): ", r9)

	var layer = ObjectAtlasScript.get_texture_layer("sofa_fabrics_atlas")
	print("Sofa fabrics atlas layer: ", layer)
	quit()
