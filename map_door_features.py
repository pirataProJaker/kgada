import bpy

# Load Texture White and inspect door seam pixels
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

body = bpy.data.objects['Body']
mesh = body.data
uv_layer = mesh.uv_layers.active.data

# Let's inspect each face around the door area and print:
# 1. 3D vertices (local coordinates)
# 2. UV vertices
# 3. Which features (A-pillar, door handle, B-pillar, C-pillar) it overlaps with!

with open(r"c:\Users\PC 1\PSX\door_features_map.txt", "w") as f:
    for i in [1, 4, 17, 19, 70, 55, 8, 9, 67, 56, 25, 24, 69, 57, 27, 64, 54, 63, 72, 10, 71]:
        p = mesh.polygons[i]
        f.write(f"\n--- FACE {i} ---\n")
        f.write(f"3D Center: ({p.center.x:.3f}, {p.center.y:.3f}, {p.center.z:.3f})\n")
        f.write(f"Normal: ({p.normal.x:.2f}, {p.normal.y:.2f}, {p.normal.z:.2f})\n")
        for li, vi in zip(p.loop_indices, p.vertices):
            v = mesh.vertices[vi]
            uv = uv_layer[li].uv
            f.write(f"  v{vi:2d}: 3D=({v.co.x:6.3f}, {v.co.y:6.3f}, {v.co.z:6.3f}) | UV=({uv.x:.4f}, {uv.y:.4f})\n")

print("door_features_map.txt written!")
