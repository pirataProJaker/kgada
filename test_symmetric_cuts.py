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
mesh = body.data

# Find symmetric pairs for all faces
sym_map = {}
for i, p1 in enumerate(mesh.polygons):
    if p1.center.x > 0.05:
        target = (-p1.center.x, p1.center.y, p1.center.z)
        best_j = -1
        best_dist = 999.0
        for j, p2 in enumerate(mesh.polygons):
            if p2.center.x < -0.05:
                d = (p2.center.x - target[0])**2 + (p2.center.y - target[1])**2 + (p2.center.z - target[2])**2
                if d < best_dist:
                    best_dist = d
                    best_j = j
        if best_dist < 0.001:
            sym_map[i] = best_j

print(f"Face 27 symmetric counterpart: {sym_map.get(27)}")
print(f"Face 17, 19, 70 symmetric counterparts: {[sym_map.get(x) for x in [17, 19, 70]]}")

# Now let's do bisect on BMesh for both sides:
bm = bmesh.new()
bm.from_mesh(mesh)

# 1. Front cut at Y = -0.653 (Both Left and Right)
left_front_faces = [f for f in bm.faces if f.index in [17, 19, 70]]
right_front_faces = [f for f in bm.faces if f.index in [sym_map[17], sym_map[19], sym_map[70]]]
front_geom = list(set([v for f in (left_front_faces + right_front_faces) for v in f.verts] +
                      [e for f in (left_front_faces + right_front_faces) for e in f.edges] +
                      left_front_faces + right_front_faces))

bmesh.ops.bisect_plane(
    bm,
    geom=front_geom,
    plane_co=Vector((0.0, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)

# 2. Rear cut on Face 27 and its symmetric counterpart (Face 124)
f27 = next(f for f in bm.faces if f.index == 27)
f27_sym_idx = sym_map[27]
f27_sym = next(f for f in bm.faces if f.index == f27_sym_idx)

# Bisect Left Face 27
geom_f27 = list(set(list(f27.verts) + list(f27.edges) + [f27]))
bmesh.ops.bisect_plane(
    bm,
    geom=geom_f27,
    plane_co=Vector((0.493, 0.486, 0.300)),
    plane_no=Vector((0.0, -0.342, 0.277))
)

# Bisect Right Face (symmetric across X = 0)
geom_f27_sym = list(set(list(f27_sym.verts) + list(f27_sym.edges) + [f27_sym]))
bmesh.ops.bisect_plane(
    bm,
    geom=geom_f27_sym,
    plane_co=Vector((-0.493, 0.486, 0.300)),
    plane_no=Vector((0.0, -0.342, 0.277))
)

bm.to_mesh(mesh)
bm.free()

print("Symmetric bisect applied successfully!")
