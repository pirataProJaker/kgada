extends SceneTree

func _init() -> void:
	var path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.user_uploaded/media_1790967656197.jpg"
	var img := Image.load_from_file(path)
	var w := img.get_width()
	var h := img.get_height()
	
	# Detectar columnas y filas analizando la luminosidad
	var col_lum: Array[float] = []
	for x in range(w):
		var sum := 0.0
		for y in range(h):
			var c := img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
		col_lum.append(sum / float(h))
		
	var row_lum: Array[float] = []
	for y in range(h):
		var sum := 0.0
		for x in range(w):
			var c := img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
		row_lum.append(sum / float(w))
		
	print("Ancho = %d, Alto = %d" % [w, h])
	
	# Umbral de negro: < 0.05
	# Imprimir segmentos no negros en X:
	var in_col := false
	var col_starts: Array[int] = []
	var col_ends: Array[int] = []
	for x in range(w):
		var val: float = col_lum[x]
		if not in_col and val > 0.05:
			in_col = true
			col_starts.append(x)
		elif in_col and val <= 0.05:
			in_col = false
			col_ends.append(x - 1)
	if in_col:
		col_ends.append(w - 1)
		
	print("Columnas detectadas (%d):" % col_starts.size())
	for i in range(col_starts.size()):
		print("  Col %d: x=%d .. %d (ancho=%d)" % [i, col_starts[i], col_ends[i], col_ends[i] - col_starts[i] + 1])

	var in_row := false
	var row_starts: Array[int] = []
	var row_ends: Array[int] = []
	for y in range(h):
		var val: float = row_lum[y]
		if not in_row and val > 0.05:
			in_row = true
			row_starts.append(y)
		elif in_row and val <= 0.05:
			in_row = false
			row_ends.append(y - 1)
	if in_row:
		row_ends.append(h - 1)
		
	print("Filas detectadas (%d):" % row_starts.size())
	for i in range(row_starts.size()):
		print("  Fila %d: y=%d .. %d (alto=%d)" % [i, row_starts[i], row_ends[i], row_ends[i] - row_starts[i] + 1])

	quit(0)
