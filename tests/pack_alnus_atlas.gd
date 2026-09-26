@tool
extends SceneTree

func _init() -> void:
	var out_dir = "res://assets/vegetation/alnus/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	# User mapping:
	# hojaAlnus1: Image 3 (media_1790204601808.png) -> anchor: (610, 1023)
	# hojaAlnus2: Image 2 (media_1790204554018.png) -> anchor: (511, 755)
	# hojaAlnus3: Image 1 (media_1790204474422.png) -> anchor: (544, 730)
	# hojaAlnus4: Image 0 (media_1790204395309.png) -> anchor: (498, 509)

	var files = [
		{"name": "hoja_alnus_1.png", "src": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204601808.png", "anchor": Vector2(610.0 / 1024.0, 1023.0 / 1024.0)},
		{"name": "hoja_alnus_2.png", "src": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204554018.png", "anchor": Vector2(511.0 / 1024.0, 755.0 / 1024.0)},
		{"name": "hoja_alnus_3.png", "src": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204474422.png", "anchor": Vector2(544.0 / 1024.0, 730.0 / 1024.0)},
		{"name": "hoja_alnus_4.png", "src": "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790204395309.png", "anchor": Vector2(498.0 / 1024.0, 509.0 / 1024.0)}
	]

	# 2x2 Atlas: 2048 x 2048
	# [0,0] = hoja_alnus_1 | [1,0] = hoja_alnus_2
	# [0,1] = hoja_alnus_3 | [1,1] = hoja_alnus_4
	var atlas = Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	var positions = [
		Vector2i(0, 0),       # variant 0: hoja_alnus_1
		Vector2i(1024, 0),    # variant 1: hoja_alnus_2
		Vector2i(0, 1024),    # variant 2: hoja_alnus_3
		Vector2i(1024, 1024)  # variant 3: hoja_alnus_4
	]

	for i in range(files.size()):
		var f = files[i]
		var img = Image.load_from_file(f.src)
		if img:
			# save individual file
			var save_indiv = out_dir + f.name
			img.save_png(save_indiv)
			print("Saved individual: ", save_indiv)

			# blit into atlas
			atlas.blit_rect(img, Rect2i(0, 0, 1024, 1024), positions[i])

	var atlas_save_path = out_dir + "alnus_leaf_atlas.png"
	atlas.save_png(atlas_save_path)
	print("Saved 2x2 atlas: ", atlas_save_path)

	quit()
