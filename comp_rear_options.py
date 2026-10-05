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

# Opción 1: Puerta 4 caras original [25, 24, 69, 57]
# (Limpia, sin huecos, sigue el pilar de la ventanilla trasera)
opt1 = extract_set(body, {25, 24, 69, 57}, "Opt1_CleanLoop")

# Opción 2: Puerta con aleta fija incluida [25, 24, 69, 57, 64, 27, 54, 72, 63]
# Pero cortando la aleta del chasis en v13 de forma limpia
opt2 = extract_set(body, {25, 24, 69, 57, 64, 27, 54, 72, 63}, "Opt2_WithQuarter")

# Set up camera looking at left-rear 3/4
cam_data = bpy.data.cameras.new("CompCam")
cam = bpy.data.objects.new("CompCam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

light = bpy.data.lights.new(name="Sun", type='SUN')
light.energy = 3.5
light_obj = bpy.data.objects.new(name="Sun", object_data=light)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(60), math.radians(20), math.radians(45))

body.hide_render = True

cam.location = (2.2, 1.2, 0.8)
cam.rotation_euler = (math.radians(70), 0.0, math.radians(115))

scene = bpy.context.scene
scene.render.resolution_x = 1000
scene.render.resolution_y = 700

# Render Option 1
opt1.hide_render = False
opt2.hide_render = True
scene.render.filepath = r"c:\Users\PC 1\PSX\comp_opt1_clean.png"
bpy.ops.render.render(write_still=True)
print("Rendered comp_opt1_clean.png")

# Render Option 2
opt1.hide_render = True
opt2.hide_render = False
scene.render.filepath = r"c:\Users\PC 1\PSX\comp_opt2_quarter.png"
bpy.ops.render.render(write_still=True)
print("Rendered comp_opt2_quarter.png")
