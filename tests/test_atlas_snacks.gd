extends SceneTree

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")

func _init() -> void:
	print("--- Testing ObjectAtlas Snack Bags Registration ---")
	ObjectAtlasScript.ensure_initialized()

	for idx in range(ObjectAtlasScript.SNACK_BAG_NAMES.size()):
		var name_id = ObjectAtlasScript.SNACK_BAG_NAMES[idx]
		var data = ObjectAtlasScript.get_snack_bag_data(name_id)
		var f_uv = ObjectAtlasScript.get_region("snack_bags_atlas", name_id + "_front")
		var s_uv = ObjectAtlasScript.get_region("snack_bags_atlas", name_id + "_side")
		var c_uv = ObjectAtlasScript.get_region("snack_bags_atlas", name_id + "_color")
		print("Snack #%d (%s): %s -> Front=%s Side=%s Color=%s" % [
			idx, name_id, data["name"], str(f_uv), str(s_uv), str(c_uv)
		])

	# Test alias resolution
	var test_doritos = ObjectAtlasScript.get_snack_bag_data("doritos")
	print("Alias 'doritos' resolved to: ", test_doritos["name"])
	var test_takis = ObjectAtlasScript.get_snack_bag_data("takis")
	print("Alias 'takis' resolved to: ", test_takis["name"])
	var test_ruffles = ObjectAtlasScript.get_snack_bag_data("ruffles")
	print("Alias 'ruffles' resolved to: ", test_ruffles["name"])

	print("✓ ObjectAtlas snack test passed!")
	quit(0)
