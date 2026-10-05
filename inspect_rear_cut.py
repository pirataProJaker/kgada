import bpy
import bmesh
from mathutils import Vector

# Inspect the exact 3D coordinates and UV coordinates of Face 27, 64, 54, 63, 72
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

body = bpy.data.objects['Body']
mesh = body.data
uv_layer = mesh.uv_layers.active.data

print("\n--- REAR DOOR INTERSECTION POLYS ---")
for fi in [24, 25, 27, 64, 54, 63, 10, 71, 72]:
    p = mesh.polygons[fi]
    print(f"\nFace {fi:2d}: Normal=({p.normal.x:.2f}, {p.normal.y:.2f}, {p.normal.z:.2f})")
    for li, vi in zip(p.loop_indices, p.vertices):
        v = mesh.vertices[vi]
        uv = uv_layer[li].uv
        print(f"  v{vi:2d}: 3D=({v.co.x:6.3f}, {v.co.y:6.3f}, {v.co.z:6.3f}) | UV=({uv.x:.4f}, {uv.y:.4f})")
