import bpy
import bmesh
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

body = bpy.data.objects['Body']
mesh = body.data

# Let's check the Y coordinates of the car:
# Front bumper is around Y = -1.8, Rear bumper is around Y = +1.8
# Let's find the 3D positions of the key vertices on the left side (X > 0):
print("--- KEY VERTICES ON LEFT SIDE ---")
for v in mesh.vertices:
    if v.co.x > 0.25 and -1.0 <= v.co.y <= 1.0:
        print(f"v{v.index:2d}: 3D=({v.co.x:6.3f}, {v.co.y:6.3f}, {v.co.z:6.3f})")

# Let's check how Y relates to U on the side of the car:
# Let's check UV U vs 3D Y for side vertices:
uv_layer = mesh.uv_layers.active.data
poly_map = []
for p in mesh.polygons:
    if p.normal.x > 0.5: # facing left
        for li, vi in zip(p.loop_indices, p.vertices):
            v = mesh.vertices[vi]
            uv = uv_layer[li].uv
            poly_map.append((vi, v.co.y, v.co.z, uv.x, uv.y))

# Sort by Y
poly_map.sort(key=lambda t: t[1])
print("\n--- 3D Y vs UV U for side vertices ---")
seen = set()
for vi, y, z, u, v in poly_map:
    if vi not in seen:
        seen.add(vi)
        print(f"v{vi:2d}: 3D Y={y:6.3f}, Z={z:6.3f} | UV U={u:6.3f}, V={v:6.3f}")
