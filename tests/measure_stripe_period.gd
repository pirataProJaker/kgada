extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/crop_r0_c6_clean.png")
	var w := img.get_width()
	var h := img.get_height()
	
	# Sample along diagonal x = y from (0,0) to (255, 255)
	# Distance along t = x + y goes from 0 to 510
	var profile: Array[float] = []
	for i in range(256):
		var c := img.get_pixel(i, i)
		# Measure yellowness: (R + G) / 2 - B
		var yellowness: float = (c.r + c.g) * 0.5 - c.b
		profile.append(yellowness)
		
	# Find autocorrelation of profile to find the exact period T
	var best_period := 0
	var best_corr := -1.0
	for lag in range(30, 150):
		var sum := 0.0
		var count := 0
		for i in range(256 - lag):
			sum += profile[i] * profile[i + lag]
			count += 1
		var avg_corr := sum / count
		if avg_corr > best_corr:
			best_corr = avg_corr
			best_period = lag
			
	print("Diagonal lag period along x=y: ", best_period, " pixels")
	# Since x=y, t = x + y = 2 * i, so along x or y axis, period is best_period
	print("Period along X or Y axis is approximately: ", best_period, " pixels")
	print("Total pixels = 256. Number of periods in tile = ", 256.0 / float(best_period))
	quit(0)
