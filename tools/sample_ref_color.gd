@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("C:/Users/PC 1/.gemini/antigravity-ide/brain/9c970330-e8c8-4c9c-92fc-e22033750d8a/.user_uploaded/media_1791160550217.png")
	if img == null: quit(); return
	# Sample on the hood and driver door of the reference image
	print("Reference hood center: ", img.get_pixel(150, 160))
	print("Reference hood highlight: ", img.get_pixel(130, 150))
	print("Reference front fender: ", img.get_pixel(90, 150))
	print("Reference front door: ", img.get_pixel(220, 155))
	quit()
