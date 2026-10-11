extends SceneTree

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

func _init() -> void:
	FurnitureTextureManagerScript.ensure_initialized()
	ObjectAtlasScript.ensure_initialized()
	
	var textures_to_check := ["cabinets", "refrigerador", "estufa", "microondas", "washer", "dryer"]
	for tex_key in textures_to_check:
		print("\n===============================")
		print("Checking '%s':" % tex_key)
		var tex_path: String = FurnitureTextureManagerScript.DEFAULT_APPLIANCE_TEXTURES[tex_key]
		var img := Image.load_from_file(tex_path)
		var img_w := img.get_width()
		var img_h := img.get_height()
		print("File: %s (%dx%d)" % [tex_path, img_w, img_h])
		
		var sub_regions: Dictionary = ObjectAtlasScript._REGIONS[tex_key]
		for r_name in sub_regions:
			var rect: Rect2 = sub_regions[r_name]["rect"]
			var px_x := int(rect.position.x * img_w)
			var px_y := int(rect.position.y * img_h)
			var px_w := int(rect.size.x * img_w)
			var px_h := int(rect.size.y * img_h)
			
			var white_count := 0
			var total_border_px := 0
			# Check all border pixels (left, right, top, bottom)
			for x in range(px_x, px_x + px_w):
				for y in [px_y, px_y + px_h - 1]:
					if x < img_w and y < img_h and x >= 0 and y >= 0:
						var c := img.get_pixel(x, y)
						if c.r > 0.98 and c.g > 0.98 and c.b > 0.98:
							white_count += 1
						total_border_px += 1
			for y in range(px_y, px_y + px_h):
				for x in [px_x, px_x + px_w - 1]:
					if x < img_w and y < img_h and x >= 0 and y >= 0:
						var c := img.get_pixel(x, y)
						if c.r > 0.98 and c.g > 0.98 and c.b > 0.98:
							white_count += 1
						total_border_px += 1
						
			var white_pct := float(white_count) / float(maxi(total_border_px, 1)) * 100.0
			print("  Region '%s': rect (%d, %d, %d, %d) -> border white: %.1f%%" % [
				r_name, px_x, px_y, px_w, px_h, white_pct
			])

	quit(0)
