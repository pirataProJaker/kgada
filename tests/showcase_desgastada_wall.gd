extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	print("=== GENERANDO MURAL SHOWCASE DE PAREDES DESGASTADAS ===")
	
	var files = [
		"pared_desgastada2.png",
		"pared_desgastada3.png",
		"pared_desgastada4.png",
		"pared_desgastada5.png",
		"pared_desgastada6.png",
		"pared_desgastada7.png",
		"pintura_desgastada.png"
	]
	
	# Creamos un mural horizontal sobre una pared con textura de estuco azul-grisáceo y ocre
	# Tamaño: 1200 x 300
	var canvas_w := 1200
	var canvas_h := 320
	var mural := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	
	# Color de pared estuco con ligero degradado
	var wall_color_base := Color(0.82, 0.73, 0.58) # Estuco ocre/arena
	for y in range(canvas_h):
		for x in range(canvas_w):
			# Sutil variación de estuco
			var noise_val = (sin(x * 0.15) * cos(y * 0.15)) * 0.02
			var col = wall_color_base + Color(noise_val, noise_val, noise_val)
			mural.set_pixel(x, y, col)
			
	var x_offset = 30
	for file_name in files:
		var path = "res://assets/textures/house/" + file_name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if not img:
			continue
			
		var iw = img.get_width()
		var ih = img.get_height()
		var y_offset = (canvas_h - ih) / 2
		
		# Blit con alfa
		for iy in range(ih):
			for ix in range(iw):
				var p = img.get_pixel(ix, iy)
				var mx = x_offset + ix
				var my = y_offset + iy
				if mx < canvas_w and my < canvas_h:
					var bg_col = mural.get_pixel(mx, my)
					var blended = bg_col.lerp(Color(p.r, p.g, p.b, 1.0), p.a)
					mural.set_pixel(mx, my, blended)
					
		x_offset += iw + 25
		
	var out_path = ARTIFACT_DIR + "/showcase_pared_desgastada_mural.png"
	mural.save_png(out_path)
	print("✓ Mural showcase guardado: ", out_path)
	quit(0)
