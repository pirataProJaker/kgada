import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']
body = data_to.objects[0]
mesh = body.data

# Let's inspect all faces on left side with 0.0 <= Y <= 0.9 and Z > 0.1
print("ALL ORIGINAL FACES IN REAR CABIN (X > 0.3):")
for f in mesh.polygons:
    if f.normal.x > 0.2 and all(mesh.vertices[vi].co.x > 0.25 for vi in f.vertices):
        ys = [mesh.vertices[vi].co.y for vi in f.vertices]
        zs = [mesh.vertices[vi].co.z for vi in f.vertices]
        if min(ys) >= 0.0 and max(ys) <= 0.9:
            print(f"Face {f.index:2d}: Center=({f.center.y:.3f}, {f.center.z:.3f}), Y=[{min(ys):.3f}..{max(ys):.3f}], Z=[{min(zs):.3f}..{max(zs):.3f}], Verts={list(f.vertices)}")
