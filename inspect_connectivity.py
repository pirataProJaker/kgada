import bpy

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']
body = data_to.objects[0]
mesh = body.data

# Let's inspect the connectivity of faces around the rear door:
# Faces: 57, 69, 24, 25, 64, 27, 54, 72, 63
target_faces = [57, 69, 24, 25, 64, 27, 54, 72, 63]
print("Target faces connectivity:")
for fid in target_faces:
    f = mesh.polygons[fid]
    print(f"Face {fid:2d}: Verts={list(f.vertices)}")
