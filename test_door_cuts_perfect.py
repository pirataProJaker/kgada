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

# 1. Front cut at Y = -0.653
faces_front = [f for f in bm.faces if f.index in [17, 19, 70]]
geom_front = list(set([v for f in faces_front for v in f.verts] + [e for f in faces_front for e in f.edges] + faces_front))
bmesh.ops.bisect_plane(
    bm,
    geom=geom_front,
    plane_co=Vector((0.48, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)

# 2. Rear cut: let's test splitting Face 27
f27 = next(f for f in bm.faces if f.index == 27)
# Subdivide or bisect Face 27 with a mid point on the dogleg:
# Mid point at (0.495, 0.460, 0.280)
# Or bisect Face 27 with plane through v26 and v9:
geom_f27 = list(set(list(f27.verts) + list(f27.edges) + [f27]))
# Plane through v26 (0.503, 0.625, 0.471) and v9 (0.484, 0.389, 0.129)
# Midpoint = (0.493, 0.507, 0.300)
# Direction = (0.019, 0.236, 0.342)
# Normal in YZ plane: (0, -0.342, 0.236)
bmesh.ops.bisect_plane(
    bm,
    geom=geom_f27,
    plane_co=Vector((0.493, 0.507, 0.300)),
    plane_no=Vector((0.0, -0.342, 0.236))
)

bm.to_mesh(body.data)
bm.free()

# Now find all front door and rear door faces:
front_door_faces = set()
rear_door_faces = set()

for f in body.data.polygons:
    cents = f.center
    vcos = [body.data.vertices[vi].co for vi in f.vertices]
    if all(v.x > 0.25 for v in vcos) and f.normal.x > 0.3:
        # Front door: Y in [-0.654, 0.011]
        if min(v.y for v in vcos) >= -0.654 and max(v.y for v in vcos) <= 0.012:
            if max(v.z for v in vcos) <= 0.835:
                front_door_faces.add(f.index)
        # Rear door:
        # Y in [0.010, 0.626]
        # Window: Face 57 (Y <= 0.525, Z >= 0.56)
        # Door body: Z < 0.57, and must be in front of the cut we made on Face 27
        if min(v.y for v in vcos) >= 0.010 and max(v.y for v in vcos) <= 0.626:
            if cents.z >= 0.56 and cents.y <= 0.525:
                rear_door_faces.add(f.index)
            elif cents.z < 0.56:
                # Check if this face is in front of the bisect plane on Face 27
                # Line: -0.342 * (y - 0.507) + 0.236 * (z - 0.300)
                # For front part (lower Y), -0.342*(y - 0.507) > 0
                val = -0.342 * (cents.y - 0.507) + 0.236 * (cents.z - 0.300)
                if val >= -0.01:
                    rear_door_faces.add(f.index)

print(f"Front Door Faces: {sorted(list(front_door_faces))}")
print(f"Rear Door Faces: {sorted(list(rear_door_faces))}")

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

# Camera looking at left side
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
scene.render.filepath = r"c:\Users\PC 1\PSX\test_doors_perfect.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_doors_perfect.png!")
