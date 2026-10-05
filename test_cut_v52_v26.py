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

# Let's find Face 54 and Face 72
f54 = next(f for f in bm.faces if f.index == 54)
f72 = next(f for f in bm.faces if f.index == 72)

# Bisect with plane passing through v52 (0.461, 0.457, 0.568) and v26 (0.503, 0.625, 0.471)
geom = list(set(list(f54.verts) + list(f54.edges) + [f54] + list(f72.verts) + list(f72.edges) + [f72]))

# Midpoint = (0.482, 0.541, 0.520)
# Line dir in YZ: (0.168, -0.097)
# Normal in YZ: (0.097, 0.168)
bmesh.ops.bisect_plane(
    bm,
    geom=geom,
    plane_co=Vector((0.482, 0.541, 0.520)),
    plane_no=Vector((0.0, 0.097, 0.168))
)

print("Bisect between v52 and v26 completed!")
bm.to_mesh(body.data)
bm.free()
