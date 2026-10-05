import bpy

img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png")
width, height = img.size
pixels = list(img.pixels) # RGBA floats

# We want to analyze row Y (V) in the door area
# Let's inspect along a horizontal line through the middle of the doors:
# V around 0.65 to 0.72 (height * V)
v_test = int(height * 0.68) # mid door height

print(f"Image size: {width}x{height}")
print(f"Scanning horizontal row at V = 0.68 (pixel y = {v_test}) for door seam lines...")

# Find dark vertical lines (seams): luminance < 0.6
seams = []
for x in range(width):
    idx = (v_test * width + x) * 4
    r, g, b = pixels[idx], pixels[idx+1], pixels[idx+2]
    lum = 0.299*r + 0.587*g + 0.114*b
    u = x / width
    if lum < 0.65:
        seams.append((x, u, lum))

print(f"Found {len(seams)} dark seam pixels along row {v_test}:")
# Cluster seams
clusters = []
curr = []
for s in seams:
    if not curr or s[0] == curr[-1][0] + 1:
        curr.append(s)
    else:
        clusters.append(curr)
        curr = [s]
if curr:
    clusters.append(curr)

for c in clusters:
    u_min = c[0][1]
    u_max = c[-1][1]
    u_mid = (u_min + u_max) / 2
    x_min = c[0][0]
    x_max = c[-1][0]
    print(f"  Seam cluster at pixels X=[{x_min:3d}..{x_max:3d}] -> U=[{u_min:.4f}..{u_max:.4f}] (center U={u_mid:.4f})")
