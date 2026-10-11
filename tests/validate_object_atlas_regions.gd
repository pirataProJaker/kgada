extends SceneTree

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

func _init() -> void:
	FurnitureTextureManagerScript.ensure_initialized()
	ObjectAtlasScript.ensure_initialized()
	
	var default_textures: Dictionary = FurnitureTextureManagerScript.DEFAULT_APPLIANCE_TEXTURES.duplicate()
	for k in FurnitureTextureManagerScript.DEFAULT_WOOD_TEXTURES:
		default_textures[k] = FurnitureTextureManagerScript.DEFAULT_WOOD_TEXTURES[k]
		
	print("==================================================")
	print("VALIDATING OBJECT ATLAS REGIONS")
	print("==================================================")
	
	var regions_dict: Dictionary = ObjectAtlasScript._REGIONS
	
	for tex_key in regions_dict:
		print("\nChecking texture: '%s'..." % tex_key)
		if not default_textures.has(tex_key):
			print("  [WARNING] Key '%s' is not in DEFAULT_APPLIANCE_TEXTURES or WOOD_TEXTURES!" % tex_key)
			continue
			
		var tex_path: String = default_textures[tex_key]
		var img := Image.load_from_file(tex_path)
		if img == null:
			print("  [ERROR] Cannot load file: %s" % tex_path)
			continue
			
		var img_w := img.get_width()
		var img_h := img.get_height()
		print("  Image size: %dx%d (from %s)" % [img_w, img_h, tex_path])
		
		var sub_regions: Dictionary = regions_dict[tex_key]
		for r_name in sub_regions:
			var r_data: Dictionary = sub_regions[r_name]
			var rect: Rect2 = r_data["rect"]
			
			var px_x := int(rect.position.x * img_w)
			var px_y := int(rect.position.y * img_h)
			var px_w := int(rect.size.x * img_w)
			var px_h := int(rect.size.y * img_h)
			
			# Check out of bounds
			if px_x < 0 or px_y < 0 or px_x + px_w > img_w or px_y + px_h > img_h:
				print("  [BOUNDS ERROR] Region '%s': pixel rect (%d, %d, %d, %d) exceeds image (%d, %d)" % [
					r_name, px_x, px_y, px_w, px_h, img_w, img_h
				])
				continue
				
			# Sample corners and edge margins to see if they hit solid white or solid black
			var top_left := img.get_pixel(px_x, px_y)
			var top_right := img.get_pixel(mini(px_x + px_w - 1, img_w - 1), px_y)
			var bot_left := img.get_pixel(px_x, mini(px_y + px_h - 1, img_h - 1))
			var bot_right := img.get_pixel(mini(px_x + px_w - 1, img_w - 1), mini(px_y + px_h - 1, img_h - 1))
			
			# Check left column for white margin
			var left_white_count := 0
			for y in range(px_y, px_y + px_h):
				var c := img.get_pixel(px_x, y)
				if c.r > 0.98 and c.g > 0.98 and c.b > 0.98:
					left_white_count += 1
			var left_white_pct := float(left_white_count) / float(maxi(px_h, 1))
			
			if left_white_pct > 0.8:
				print("  [WHITE BLEED ALERT!] Region '%s': Left border is %.1f%% pure white! Pixel x=%d" % [
					r_name, left_white_pct * 100.0, px_x
				])
			else:
				print("  ✓ '%s': rect (%d, %d, %d, %d) OK (corners sampled)" % [r_name, px_x, px_y, px_w, px_h])
				
	print("\nValidation complete.")
	quit(0)
