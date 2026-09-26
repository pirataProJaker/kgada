@tool
extends SceneTree

func _init() -> void:
	var files = [
		{"name": "col0_media_1790204395309", "path": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204395309.png"},
		{"name": "col1_media_1790204474422", "path": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204474422.png"},
		{"name": "col2_media_1790204554018", "path": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204554018.png"},
		{"name": "col3_media_1790204601808", "path": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204601808.png"}
	]

	# Let's save each of the 4 images individually with the user's specific coordinates marked
	# User specs:
	# hojaAlnus4: 498, 509
	# hojaAlnus3: 544, 730
	# hojaAlnus2: 511, 755
	# hojaAlnus1: 610, 1027 (clamp to 1023)
	var marks = {
		0: [Vector2i(498, 509), "hojaAlnus4 (498,509)"],
		1: [Vector2i(544, 730), "hojaAlnus3 (544,730)"],
		2: [Vector2i(511, 755), "hojaAlnus2 (511,755)"],
		3: [Vector2i(610, 1023), "hojaAlnus1 (610,1027)"]
	}

	for i in range(4):
		var img = Image.load_from_file(files[i].path)
		var m = marks[i]
		var pt = m[0]
		var label = m[1]
		print("Image ", i, " (", files[i].name, ") marked with ", label)
		# Draw a 10px red ring with center dot
		for dy in range(-15, 16):
			for dx in range(-15, 16):
				var d = Vector2(dx, dy).length()
				var px = pt.x + dx
				var py = pt.y + dy
				if px >= 0 and px < 1024 and py >= 0 and py < 1024:
					if d < 3.0 or (d >= 8.0 and d <= 11.0):
						img.set_pixel(px, py, Color.RED)
		img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/marked_leaf_%d.png" % i)

	quit()
