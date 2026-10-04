extends SceneTree

func _init() -> void:
	var path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.system_generated/logs/transcript_full.jsonl"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("No se pudo abrir el archivo transcript_full")
		quit(1)
		return
	
	var last_user_line := ""
	while not file.eof_reached():
		var line := file.get_line()
		if line.contains("\"step_index\":7022") or line.contains("\"step_index\": 7022"):
			last_user_line = line
			break
	
	print("STEP 7022 FULL:")
	print(last_user_line)
	
	print("LAST USER LINE:")
	print(last_user_line)
	quit(0)
