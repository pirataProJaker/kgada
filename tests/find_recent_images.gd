extends SceneTree

func _init() -> void:
	var base := "C:/Users/Eduardo Contreras/.gemini"
	var found: Array[String] = []
	scan_dir(base, found)
	print("FOUND %d RECENT PNG FILES:" % found.size())
	for p in found:
		print(" - %s" % p)
	quit(0)

func scan_dir(path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir: return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full = path + "/" + name
			if dir.current_is_dir():
				if not name.begins_with(".git"):
					scan_dir(full, results)
			elif name.ends_with(".png") or name.ends_with(".jpg") or name.ends_with(".webp"):
				var mod := FileAccess.get_modified_time(full)
				# Archivos modificados en los últimos 30 minutos (1800 seg)
				var now := int(Time.get_unix_time_from_system())
				if now - mod < 1800:
					results.append(full)
		name = dir.get_next()
