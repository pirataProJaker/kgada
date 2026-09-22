@tool
extends SceneTree

## Generador de textura pixel art de césped "MMMM" que encaja estrictamente
## dentro del triángulo unitario (UV: Base (0,1)-(1,1), Cúspide (0.5, 0)).

func _init() -> void:
	var width := 64
	var height := 64
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # Transparente
	
	# Paleta retro PSX con sombreado de contorno y volumen
	var col_dark_border := Color(0.06, 0.16, 0.04, 1.0)
	var col_root := Color(0.09, 0.22, 0.06, 1.0)
	var col_mid_dark := Color(0.18, 0.44, 0.12, 1.0)
	var col_mid_bright := Color(0.28, 0.64, 0.18, 1.0)
	var col_highlight := Color(0.44, 0.78, 0.24, 1.0)
	var col_tip := Color(0.58, 0.86, 0.28, 1.0)
	
	# 5 briznas formando "MMMM" con base ancha y puntas convergentes al triángulo:
	# [x_base, x_tip, y_tip, half_width]
	var blades = [
		[10.0, 18.0, 32.0, 4.0],  # Brizna 1 (izq baja)
		[21.0, 26.0, 15.0, 4.5],  # Brizna 2 (izq alta)
		[32.0, 32.0,  3.0, 5.0],  # Brizna 3 (centro, pico más alto)
		[43.0, 38.0, 15.0, 4.5],  # Brizna 4 (der alta)
		[54.0, 46.0, 32.0, 4.0]   # Brizna 5 (der baja)
	]
	
	for y in range(height):
		var v = float(y) / float(height - 1) # 0 arriba, 1 abajo
		# Triángulo: ancho completo (0 a 1) en v=1, punto central (0.5) en v=0
		var min_u = 0.5 * (1.0 - v)
		var max_u = 1.0 - min_u
		var min_x = min_u * float(width - 1)
		var max_x = max_u * float(width - 1)
		
		for x in range(width):
			# Descartar cualquier píxel fuera del triángulo geométrico
			if float(x) < min_x or float(x) > max_x:
				continue
			
			var in_blade = false
			var min_dist_center = 999.0
			var blade_t = 0.0
			var is_border = false
			
			for b in blades:
				var bx_base: float = b[0]
				var bx_tip: float = b[1]
				var by_tip: float = b[2]
				var b_w: float = b[3]
				
				if y >= by_tip and y < height:
					var t = float(y - by_tip) / float(height - by_tip) # 0 en punta, 1 en base
					var cur_center = lerpf(bx_tip, bx_base, t)
					var cur_w = lerpf(0.9, b_w, pow(t, 0.75))
					var dist = absf(float(x) - cur_center)
					
					if dist <= cur_w:
						in_blade = true
						var local_dist = dist / maxf(cur_w, 0.01)
						if local_dist < min_dist_center:
							min_dist_center = local_dist
							blade_t = 1.0 - t
							if cur_w - dist < 1.0:
								is_border = true
			
			if in_blade:
				var c: Color
				if is_border:
					c = col_dark_border
				elif min_dist_center < 0.35 and blade_t > 0.35:
					c = col_mid_bright.lerp(col_highlight, blade_t)
					if blade_t > 0.85:
						c = col_tip
				else:
					if blade_t < 0.3:
						c = col_root.lerp(col_mid_dark, blade_t / 0.3)
					elif blade_t < 0.7:
						c = col_mid_dark.lerp(col_mid_bright, (blade_t - 0.3) / 0.4)
					else:
						c = col_mid_bright.lerp(col_highlight, (blade_t - 0.7) / 0.3)
				
				img.set_pixel(x, y, c)
	
	img.save_png("res://world/vegetation/grass/grass_m_texture.png")
	print("✓ Textura de césped triangular MMMM corregida guardada en: res://world/vegetation/grass/grass_m_texture.png")
	quit(0)
