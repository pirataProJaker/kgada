@tool
extends SceneTree

func _init() -> void:
	var user_dir = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/"
	var da = DirAccess.open(user_dir)
	if da:
		da.list_dir_begin()
		var fn = da.get_next()
		while fn != "":
			if not da.current_is_dir():
				var p = user_dir + fn
				var img = Image.load_from_file(p)
				if img:
					print(fn, " size=", img.get_size(), " format=", img.get_format(), " used_rect=", img.get_used_rect())
			fn = da.get_next()
	quit()
