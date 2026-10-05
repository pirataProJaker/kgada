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
bm = bmesh.new()
bm.from_mesh(body.data)

f27 = next(f for f in bm.faces if f.index == 27)
print("Original Face 27:")
for v in f27.verts:
    print(f"  v: 3D=({v.co.x:.3f}, {v.co.y:.3f}, {v.co.z:.3f})")

# In Face 27, verts are:
# v25: (0.500, 0.610, 0.139) - bottom rear (in wheel arch)
# v26: (0.503, 0.625, 0.471) - top rear (behind handle)
# v11: (0.503, 0.414, 0.388) - top front (mid body line)
# v9:  (0.484, 0.389, 0.129) - bottom front (in front of wheel)

# Let's inspect the UVs of Face 27:
uv_layer = bm.loops.layers.uv.active
for l in f27.loops:
    print(f"  Loop at {l.vert.co.y:.3f}, {l.vert.co.z:.3f} -> UV=({l[uv_layer].uv.x:.3f}, {l[uv_layer].uv.y:.3f})")

# Look at user red line for the dogleg:
# At Z = 0.471 (top of f27), U = 0.717 -> Y = 0.625 (v26)
# At Z = 0.350, U = 0.670 -> Y = 0.488
# At Z = 0.250, U = 0.640 -> Y = 0.400
# At Z = 0.129 (bottom of f27), U = 0.639 -> Y = 0.389 (v9)

# Notice how the user curve goes:
# It's an arc curving around the wheel!
# If we cut from v26 (0.503, 0.625, 0.471) through mid-point (0.495, 0.460, 0.280) to v9 (0.484, 0.389, 0.129):
# The door gets the front part (which is white body paint).
# The chassis gets the rear part (which contains the black wheel cutout!).

bm.free()
