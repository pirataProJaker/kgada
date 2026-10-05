import bpy

img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png")
width, height = img.size
pixels = list(img.pixels)

# Let's inspect rows around the door handle and window
# Door handle is around V = 0.71 (row 182)
# Window is around V = 0.80 (row 205)
# Waistline is around V = 0.65 (row 166)

with open(r"c:\Users\PC 1\PSX\texture_pixel_map.txt", "w") as f:
    for y in range(160, 215, 5):
        f.write(f"\n--- ROW Y = {y} (V = {y/256:.3f}) ---\n")
        line = ""
        for x in range(50, 210): # U from ~0.20 to ~0.82
            idx = (y * width + x) * 4
            lum = 0.299*pixels[idx] + 0.587*pixels[idx+1] + 0.114*pixels[idx+2]
            # Use ASCII character for luminance
            if lum < 0.2:
                char = "#" # very dark (window or deep seam)
            elif lum < 0.4:
                char = "="
            elif lum < 0.6:
                char = "-" # seam / crease / shadow
            elif lum < 0.8:
                char = "."
            else:
                char = " " # white car body
            line += char
        f.write(line + "\n")

print("texture_pixel_map.txt written!")
