import bpy
import bmesh
from mathutils import Vector
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']
    data_to.materials = data_from.materials
    data_to.images = data_from.images

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

tex_img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png")
for mat in bpy.data.materials:
    mat.use_backface_culling = False
    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                node.image = tex_img
                node.interpolation = 'Closest'

body = bpy.data.objects['Body']

# Let's inspect cutting on a duplicate of Body
bm = bmesh.new()
bm.from_mesh(body.data)

# 1. Front Cut: Bisect plane at Y = -0.653, normal (0, 1, 0)
# We only want to cut faces in front door region (X > 0.3, -0.9 < Y < -0.4)
faces_to_cut_front = [f for f in bm.faces if any(v.co.x > 0.3 for v in f.verts) and any(v.co.y < -0.5 for v in f.verts) and any(v.co.y > -0.8 for v in f.verts)]
print(f"Faces to bisect front: {[f.index for f in faces_to_cut_front]}")

res = bmesh.ops.bisect_plane(
    bm,
    geom=faces_to_cut_front,
    plane_co=Vector((0.5, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)

# 2. Rear Cut: On Face 27, cut from v26 to v9 or along the wheel arch
# Let's find the face corresponding to Face 27
# Face 27 has verts near (0.5, 0.625, 0.471) and (0.484, 0.389, 0.129)
f27 = None
for f in bm.faces:
    cents = f.calc_center_median()
    if cents.x > 0.4 and 0.45 < cents.y < 0.55 and 0.25 < cents.z < 0.35:
        f27 = f
        break

print(f"Found f27: {f27}")

# Let's test bisecting f27 along the dogleg line:
# From user's red curve:
# Top point: near v26 (0.503, 0.625, 0.471)
# Bottom point: near v9 (0.484, 0.389, 0.129)
# Mid point on dogleg: Y ~ 0.45, Z ~ 0.25
# Let's bisect f27 with plane passing through (0.503, 0.625, 0.471) and (0.484, 0.389, 0.129)
# Normal to line from v9 to v26 in YZ plane:
# dir = (0, 0.625 - 0.389, 0.471 - 0.129) = (0, 0.236, 0.342)
# perp = (0, -0.342, 0.236)
if f27:
    bmesh.ops.bisect_plane(
        bm,
        geom=[f27],
        plane_co=Vector((0.50, 0.507, 0.30)),
        plane_no=Vector((0.0, -0.342, 0.236))
    )

bm.to_mesh(body.data)
bm.free()

print("Bisect operations applied successfully!")
