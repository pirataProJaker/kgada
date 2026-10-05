import bpy
import numpy as np

img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png")
w, h = img.size
pixels = np.array(img.pixels[:]).reshape((h, w, 4))

print("Texture pixels around dogleg (X: 160..185, Y: 155..185):")
print("   " + "".join(f"{x:3d}" for x in range(160, 185, 2)))
for y in range(185, 154, -2):
    row_str = f"{y:3d} "
    for x in range(160, 185, 2):
        r, g, b, a = pixels[y, x]
        lum = 0.299*r + 0.587*g + 0.114*b
        if lum < 0.15:
            ch = " #" # black wheel arch
        elif lum < 0.40:
            ch = " ." # dark gray seam/shadow
        elif lum < 0.70:
            ch = " -" # gray flare/trim
        else:
            ch = "  " # white body
        row_str += ch
    print(row_str)
