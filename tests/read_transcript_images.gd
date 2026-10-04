extends SceneTree

func _init() -> void:
	var file = FileAccess.open("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.system_generated/logs/transcript_full.jsonl", FileAccess.READ)
	if not file:
		print("No se pudo abrir transcript_full.jsonl")
		quit(1)
		return

	while not file.eof_reached():
		var line = file.get_line()
		if line.contains('"step_index":4525') or line.contains('"step_index":4527'):
			var parsed = JSON.parse_string(line)
			if parsed:
				print("Step: ", parsed.get("step_index"), " Keys: ", parsed.keys())
				for k in parsed.keys():
					if k != "content":
						print("   ", k, " => ", parsed[k])
				var content_str: String = parsed.get("content", "")
				if content_str.contains(".png") or content_str.contains(".jpg"):
					print("   Found media in content!")
	quit(0)
