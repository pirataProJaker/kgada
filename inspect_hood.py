import bpy

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=blend_path)

h = bpy.data.objects["Part_Hood"]
print("Hood Polygons:")
for f in h.data.polygons:
    vcos = [h.data.vertices[vi].co for vi in f.vertices]
    print(f"Face {f.index}: {[(v.x, v.y, v.z) for v in vcos]}")
