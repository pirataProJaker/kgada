extends SceneTree

func _init() -> void:
	var dir = DirAccess.open("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.tempmediaStorage")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
				var full_path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.tempmediaStorage/" + file_name
				var f = FileAccess.open(full_path, FileAccess.READ)
				if f:
					var sz = f.get_length()
					# Check files between 50KB and 500KB
					if sz > 30000 and sz < 600000:
						var img = Image.load_from_file(full_path)
						if img and (img.get_width() == 512 or img.get_width() == 768 or img.get_width() == 1024 or img.get_width() == 256):
							print(file_name, " -> Width: ", img.get_width(), " Height: ", img.get_height(), " Len: ", sz)
			file_name = dir.get_next()
	quit(0)
