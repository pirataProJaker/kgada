import bpy
import bmesh
import math
from mathutils import Vector, Matrix

# Let's inspect the original mesh and see how to cut it precisely along the door lines
bpy.ops.wm.read_factory_settings(use_empty=True)
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']
    data_to.materials = data_from.materials
    data_to.images = data_from.images

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

body = bpy.data.objects['Body']
mesh = body.data

# Let's print all vertices on the left side (X > 0.3) around the doors:
print("\n--- VERTICES AROUND DOORS (X > 0.3, -1.0 < Y < 1.0) ---")
verts_side = [v for v in mesh.vertices if v.co.x > 0.3 and -1.0 < v.co.y < 1.0]
verts_side.sort(key=lambda v: (round(v.co.y, 3), round(v.co.z, 3)))
for v in verts_side:
    print(f"v{v.index:2d}: ({v.co.x:6.3f}, {v.co.y:6.3f}, {v.co.z:6.3f})")

