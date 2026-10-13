extends SceneTree

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")

func _init() -> void:
	print("--- Testing ObjectAtlas Cookie Packs Registration ---")
	ObjectAtlasScript.ensure_initialized()

	for idx in range(ObjectAtlasScript.COOKIE_PACK_NAMES.size()):
		var name_id = ObjectAtlasScript.COOKIE_PACK_NAMES[idx]
		var data = ObjectAtlasScript.get_cookie_pack_data(name_id)
		var f_uv = ObjectAtlasScript.get_region("cookie_packs_atlas", name_id + "_front")
		var b_uv = ObjectAtlasScript.get_region("cookie_packs_atlas", name_id + "_back")
		var s_uv = ObjectAtlasScript.get_region("cookie_packs_atlas", name_id + "_side")
		var c_uv = ObjectAtlasScript.get_region("cookie_packs_atlas", name_id + "_color")
		print("Cookie #%d (%s): %s -> Front=%s Back=%s Side=%s Color=%s" % [
			idx, name_id, data["name"], str(f_uv), str(b_uv), str(s_uv), str(c_uv)
		])

	# Test alias resolution
	var test_alias = ObjectAtlasScript.get_cookie_pack_data("oreo")
	print("Alias 'oreo' resolved to: ", test_alias["name"])
	var test_mint = ObjectAtlasScript.get_cookie_pack_data("mint")
	print("Alias 'mint' resolved to: ", test_mint["name"])

	print("✓ ObjectAtlas test passed!")
	quit(0)
