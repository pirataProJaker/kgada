import bpy
import bmesh
import math
from mathutils import Vector, Euler

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

# Let's test the face sets:
# Front Door: {17, 19, 70, 55, 8, 9, 67, 56}
# Option A for Rear Door: {25, 24, 69, 57, 27, 64} (6 faces - includes rear handle and dogleg)
# Option B for Rear Door: {25, 24, 69, 57, 27, 64, 54, 63} (8 faces - includes quarter glass)

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

fd = extract_set(body, {17, 19, 70, 55, 8, 9, 67, 56}, "FrontDoor")
rd_a = extract_set(body, {25, 24, 69, 57, 27, 64}, "RearDoor_A")
rd_b = extract_set(body, {25, 24, 69, 57, 27, 64, 54, 63}, "RearDoor_B")

# Set up camera looking directly at the left side
cam_data = bpy.data.cameras.new("SideCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 3.2
cam_obj = bpy.data.objects.new("SideCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

# Left side in original blend is +X: look from (+3, -0.2, 0.45) towards (0, -0.2, 0.45)
cam_obj.location = (3.0, -0.15, 0.45)
cam_obj.rotation_euler = (math.radians(90), 0, math.radians(90))

# Lights
light = bpy.data.lights.new(name="Sun", type='SUN')
light.energy = 3.5
light_obj = bpy.data.objects.new(name="Sun", object_data=light)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(60), math.radians(20), math.radians(45))

# Hide body, show Front Door + RearDoor_A
body.hide_render = True
rd_b.hide_render = True
rd_a.hide_render = False
fd.hide_render = False

scene = bpy.context.scene
scene.render.resolution_x = 1000
scene.render.resolution_y = 600

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\test_doors_option_A.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_doors_option_A.png")

# Now show Front Door + RearDoor_B
rd_a.hide_render = True
rd_b.hide_render = False
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\test_doors_option_B.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_doors_option_B.png")
