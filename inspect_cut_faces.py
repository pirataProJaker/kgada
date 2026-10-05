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

# Let's check the faces on the left side:
# Front area:
# Face 1: (v3, v18, v15)
# Face 4: (v15, v18, v58)
# Face 17: (v6, v8, v16, v17)
# Face 19: (v8, v57, v58, v16)
# Face 70: (v58, v57, v50, v15)
# Face 55: (v15, v50, v7)
# Let's inspect each of these faces:
front_faces = [1, 4, 17, 19, 70, 55]
print("--- FRONT FACES DETAILS ---")
for fid in front_faces:
    f = mesh.polygons[fid]
    vcos = [mesh.vertices[vi].co for vi in f.vertices]
    y_min = min(v.y for v in vcos)
    y_max = max(v.y for v in vcos)
    z_min = min(v.z for v in vcos)
    z_max = max(v.z for v in vcos)
    print(f"Face {fid:2d}: Y=[{y_min:6.3f}..{y_max:6.3f}], Z=[{z_min:6.3f}..{z_max:6.3f}] Verts={list(f.vertices)}")

print("\n--- REAR FACES DETAILS ---")
rear_faces = [25, 24, 69, 57, 27, 64, 54, 63, 72, 10, 71]
for fid in rear_faces:
    f = mesh.polygons[fid]
    vcos = [mesh.vertices[vi].co for vi in f.vertices]
    y_min = min(v.y for v in vcos)
    y_max = max(v.y for v in vcos)
    z_min = min(v.z for v in vcos)
    z_max = max(v.z for v in vcos)
    print(f"Face {fid:2d}: Y=[{y_min:6.3f}..{y_max:6.3f}], Z=[{z_min:6.3f}..{z_max:6.3f}] Verts={list(f.vertices)}")
