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
bm = bmesh.new()
bm.from_mesh(body.data)

# 1. Front bisect at Y = -0.653
faces_front = [f for f in bm.faces if f.index in [17, 19, 70]]
geom_front = list(set([v for f in faces_front for v in f.verts] + [e for f in faces_front for e in f.edges] + faces_front))
bmesh.ops.bisect_plane(
    bm,
    geom=geom_front,
    plane_co=Vector((0.48, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)

# 2. Rear 2-segment cut on Face 27
# Segment 1: from v26 (0.503, 0.625, 0.471) to knee (0.495, 0.460, 0.280)
# Plane through v26 and knee:
# midpoint = (0.499, 0.542, 0.375)
# dir = (0, 0.460 - 0.625, 0.280 - 0.471) = (0, -0.165, -0.191)
# normal in YZ = (0, -0.191, 0.165)
f27 = next(f for f in bm.faces if f.index == 27)
geom_f27 = list(set(list(f27.verts) + list(f27.edges) + [f27]))
res1 = bmesh.ops.bisect_plane(
    bm,
    geom=geom_f27,
    plane_co=Vector((0.499, 0.542, 0.375)),
    plane_no=Vector((0.0, -0.191, 0.165))
)

# Segment 2: from knee (0.495, 0.460, 0.280) to v9 (0.484, 0.389, 0.129)
# Cut the lower part:
faces_lower = [f for f in bm.faces if f.normal.x > 0.4 and 0.35 < f.calc_center_median().y < 0.55 and f.calc_center_median().z < 0.30]
geom_lower = list(set([v for f in faces_lower for v in f.verts] + [e for f in faces_lower for e in f.edges] + faces_lower))
# midpoint between knee and v9 = (0.490, 0.425, 0.205)
# dir = (0, 0.389 - 0.460, 0.129 - 0.280) = (0, -0.071, -0.151)
# normal in YZ = (0, -0.151, 0.071)
bmesh.ops.bisect_plane(
    bm,
    geom=geom_lower,
    plane_co=Vector((0.490, 0.425, 0.205)),
    plane_no=Vector((0.0, -0.151, 0.071))
)

bm.to_mesh(body.data)
bm.free()

# Front Door faces:
front_door_faces = set()
for f in body.data.polygons:
    vcos = [body.data.vertices[vi].co for vi in f.vertices]
    if all(v.x > 0.25 for v in vcos) and f.normal.x > 0.3:
        if min(v.y for v in vcos) >= -0.654 and max(v.y for v in vcos) <= 0.012:
            if max(v.z for v in vcos) <= 0.835:
                front_door_faces.add(f.index)

# Rear Door faces:
rear_door_faces = set()
for f in body.data.polygons:
    cents = f.center
    vcos = [body.data.vertices[vi].co for vi in f.vertices]
    if all(v.x > 0.25 for v in vcos) and f.normal.x > 0.3:
        if min(v.y for v in vcos) >= 0.010 and max(v.y for v in vcos) <= 0.626:
            # Window
            if cents.z >= 0.56 and cents.y <= 0.525:
                rear_door_faces.add(f.index)
            # Door skin
            elif cents.z < 0.56:
                # Must be in front of the cut:
                # At top (z > 0.28): plane 1: -0.191 * (y - 0.542) + 0.165 * (z - 0.375)
                # At bottom (z <= 0.28): plane 2: -0.151 * (y - 0.425) + 0.071 * (z - 0.205)
                if cents.z > 0.28:
                    val = -0.191 * (cents.y - 0.542) + 0.165 * (cents.z - 0.375)
                    if val >= -0.01:
                        rear_door_faces.add(f.index)
                else:
                    val = -0.151 * (cents.y - 0.425) + 0.071 * (cents.z - 0.205)
                    if val >= -0.01:
                        rear_door_faces.add(f.index)

def extract_set(src_obj, faces, name):
    bm = bmesh.new()
    bm.from_mesh(src_obj.data)
    faces_to_del = [f for f in bm.faces if f.index not in faces]
    bmesh.ops.delete(bm, geom=faces_to_del, context='FACES_ONLY')
    verts_to_del = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=verts_to_del, context='VERTS')
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    for m in src_obj.data.materials:
        obj.data.materials.append(m)
    bpy.context.scene.collection.objects.link(obj)
    return obj

fd = extract_set(body, front_door_faces, "FrontDoor")
rd = extract_set(body, rear_door_faces, "RearDoor")

cam_data = bpy.data.cameras.new("SideCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 2.4
cam_obj = bpy.data.objects.new("SideCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = (3.0, -0.05, 0.45)
cam_obj.rotation_euler = (math.radians(90), 0, math.radians(90))

light = bpy.data.lights.new(name="Sun", type='SUN')
light.energy = 3.5
light_obj = bpy.data.objects.new(name="Sun", object_data=light)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(60), math.radians(20), math.radians(45))

body.hide_render = True
scene = bpy.context.scene
scene.render.resolution_x = 1200
scene.render.resolution_y = 600
scene.render.filepath = r"c:\Users\PC 1\PSX\test_doors_perfect_v3.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_doors_perfect_v3.png!")
