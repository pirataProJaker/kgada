extends SceneTree

func _init() -> void:
	var dir = DirAccess.open("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.tempmediaStorage")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var count = 0
		while file_name != "":
			if file_name.ends_with(".png"):
				var full_path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.tempmediaStorage/" + file_name
				var img = Image.load_from_file(full_path)
				if img and img.get_height() >= 512:
					var bottom_px = img.get_pixel(img.get_width() / 2, img.get_height() - 20)
					var top_px = img.get_pixel(img.get_width() / 2, 20)
					if bottom_px.r < 0.01 and bottom_px.g < 0.01 and bottom_px.b < 0.01 and (top_px.r > 0.05 or top_px.g > 0.05 or top_px.b > 0.05):
						print("FOUND CANDIDATE: ", file_name, " size: ", img.get_size())
			file_name = dir.get_next()
	quit(0)
