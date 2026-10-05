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

# Pass faces + edges + verts to geom
faces_front = [f for f in bm.faces if f.index in [17, 19, 70]]
geom_front = list(set([v for f in faces_front for v in f.verts] + [e for f in faces_front for e in f.edges] + faces_front))

res = bmesh.ops.bisect_plane(
    bm,
    geom=geom_front,
    plane_co=Vector((0.48, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)
print(f"Bisect result geom count: {len(res.get('geom', []))}")
print(f"Bisect cut geom count: {len(res.get('geom_cut', []))}")

print("\n--- FACES AFTER FRONT BISECT AROUND Y = -0.653 ---")
for f in bm.faces:
    if f.normal.x > 0.3 and all(v.co.x > 0.25 for v in f.verts):
        ys = [v.co.y for v in f.verts]
        zs = [v.co.z for v in f.verts]
        if -0.85 < min(ys) and max(ys) < -0.2:
            print(f"Face {f.index:2d}: Y=[{min(ys):.3f}..{max(ys):.3f}], Z=[{min(zs):.3f}..{max(zs):.3f}], Center=({f.calc_center_median().y:.3f}, {f.calc_center_median().z:.3f})")

bm.free()
