extends SceneTree

func _init() -> void:
	var dir = DirAccess.open("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.tempmediaStorage")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var latest_files := []
		while file_name != "":
			if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
				var full_path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.tempmediaStorage/" + file_name
				var modified = FileAccess.get_modified_time(full_path)
				latest_files.append({"name": file_name, "time": modified, "path": full_path})
			file_name = dir.get_next()
		latest_files.sort_custom(func(a, b): return a.time > b.time)
		for i in range(min(15, latest_files.size())):
			var item = latest_files[i]
			var img = Image.load_from_file(item.path)
			var sz = img.get_size() if img else Vector2i.ZERO
			print(item.name, " | ", sz, " | ", item.time)
	quit(0)
