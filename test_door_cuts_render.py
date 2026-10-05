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
# Cut only on side faces X > 0.35, Z < 0.55
front_side_faces = [
    f for f in bm.faces
    if all(v.co.x > 0.35 for v in f.verts)
    and any(-0.85 < v.co.y < -0.45 for v in f.verts)
    and any(v.co.z < 0.55 for v in f.verts)
]
bmesh.ops.bisect_plane(
    bm,
    geom=front_side_faces,
    plane_co=Vector((0.48, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)

# 2. Rear cut on Face 27
# Face 27 is the quad between Y ~ 0.39 and Y ~ 0.62, Z between 0.13 and 0.47
f27 = None
for f in bm.faces:
    cents = f.calc_center_median()
    if cents.x > 0.45 and 0.45 < cents.y < 0.55 and 0.25 < cents.z < 0.35:
        f27 = f
        break

if f27:
    # Bisect from v26 (0.503, 0.625, 0.471) to v9 (0.484, 0.389, 0.129)
    bmesh.ops.bisect_plane(
        bm,
        geom=[f27],
        plane_co=Vector((0.50, 0.507, 0.30)),
        plane_no=Vector((0.0, -0.342, 0.236))
    )

bm.to_mesh(body.data)
bm.free()

# Now let's identify the faces belonging to Front Door and Rear Door:
# Front Door: X > 0.35, -0.653 <= Y <= 0.011, and (Z < 0.55 or is front window)
# Rear Door: X > 0.35, 0.011 <= Y <= 0.625
front_door_faces = set()
rear_door_faces = set()

for f in body.data.polygons:
    cents = f.center
    vcos = [body.data.vertices[vi].co for vi in f.vertices]
    # Check left side
    if all(v.x > 0.25 for v in vcos):
        # Front door region: Y between -0.654 and 0.012
        if all(v.y >= -0.654 for v in vcos) and all(v.y <= 0.012 for v in vcos):
            # Exclude roof if any
            if any(v.z < 0.83 for v in vcos) and f.normal.x > 0.3:
                front_door_faces.add(f.index)
        # Rear door region:
        # Window face Face 57: Y between 0.010 and 0.525, Z between 0.56 and 0.83
        # Door body: Y between 0.010 and 0.626, Z < 0.57
        # And must be in front of the cut we made on Face 27!
        if all(v.y >= 0.010 for v in vcos) and f.normal.x > 0.3:
            # Check if this is the rear window (Face 57 equivalent)
            if cents.y < 0.45 and cents.z > 0.55 and cents.z < 0.83:
                rear_door_faces.add(f.index)
            # Check if this is mid/lower door:
            elif cents.z <= 0.55:
                # Must be in front of dogleg line (0.342 * (y - 0.389) - 0.236 * (z - 0.129) <= 0)
                # Let's check center:
                y = cents.y
                z = cents.z
                # At handle level (z ~ 0.45), y up to 0.625 is inside
                # At rocker level (z ~ 0.13), y up to 0.40 is inside
                line_val = 0.342 * (y - 0.389) - 0.236 * (z - 0.129)
                if line_val <= 0.01 and y <= 0.63:
                    rear_door_faces.add(f.index)

print(f"Front Door Faces count: {len(front_door_faces)}, indices: {sorted(list(front_door_faces))}")
print(f"Rear Door Faces count: {len(rear_door_faces)}, indices: {sorted(list(rear_door_faces))}")

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

fd = extract_set(body, front_door_faces, "FrontDoor_Cut")
rd = extract_set(body, rear_door_faces, "RearDoor_Cut")

# Render side view of the doors
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
scene.render.filepath = r"c:\Users\PC 1\PSX\test_doors_after_cut.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_doors_after_cut.png!")
