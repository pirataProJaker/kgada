import bpy

# Inspect the texture image
img = bpy.data.images.get('Texture White.png')
if not img:
    for im in bpy.data.images:
        print("Found image:", im.name)
        img = im
        break

print(f"Image {img.name}: {img.size[0]}x{img.size[1]}")
# Let's save a visualization with wireframe UV overlay on Texture White
import bpy

# Set up UV texture export or render
