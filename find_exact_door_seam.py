import bpy
import numpy as np

img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png")
w, h = img.size
pixels = np.array(img.pixels[:]).reshape((h, w, 4))

# Let's inspect the entire side profile from X=130 to X=195, Y=145 to Y=215
# This covers the B-pillar to rear wheel
print(f"Texture White.png: {w}x{h}")
print("Scanning side area for rear door seam and features...")

# Let's find every pixel that is darker than the white car body (which is lum > 0.85)
# In each row Y, print the X positions of dark lines
for y in range(215, 145, -2):
    dark_xs = []
    for x in range(130, 205):
        r, g, b, a = pixels[y, x]
        lum = 0.299*r + 0.587*g + 0.114*b
        if lum < 0.80:
            dark_xs.append((x, lum))
    
    # Format row
    row_repr = f"Y={y:3d} (V={y/256:.3f}): "
    line_map = [" "] * (205 - 130)
    for x, lum in dark_xs:
        if lum < 0.20:
            ch = "#" # black (window, wheel, handle cavity)
        elif lum < 0.50:
            ch = "=" # dark line
        elif lum < 0.75:
            ch = "." # faint seam line
        else:
            ch = "-" # light gray
        line_map[x - 130] = ch
    row_repr += "".join(line_map)
    print(row_repr)
