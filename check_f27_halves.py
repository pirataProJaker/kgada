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
geom_f27 = list(set(list(f27.verts) + list(f27.edges) + [f27]))
res = bmesh.ops.bisect_plane(
    bm,
    geom=geom_f27,
    plane_co=Vector((0.493, 0.507, 0.300)),
    plane_no=Vector((0.0, -0.342, 0.236))
)

print(f"Cut geom faces: {[e.index for e in res.get('geom', []) if isinstance(e, bmesh.types.BMFace)]}")

for f in bm.faces:
    if f.index in [27, 88] or (f.normal.x > 0.4 and 0.45 < f.calc_center_median().y < 0.60 and f.calc_center_median().z < 0.45):
        cents = f.calc_center_median()
        vcos = [v.co for v in f.verts]
        print(f"Face {f.index}: Center=({cents.y:.3f}, {cents.z:.3f}), MaxY={max(v.y for v in vcos):.3f}, MinY={min(v.y for v in vcos):.3f}")

bm.free()
