import bpy
import math

obj = bpy.data.objects['Body']
mesh = obj.data

# Create materials with distinct solid colors
def create_mat(name, color):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Roughness'].default_value = 0.5
    return mat

mat_chassis = create_mat("M_Chassis", (0.85, 0.85, 0.85, 1.0))
mat_hood    = create_mat("M_Hood",    (1.0, 0.8, 0.1, 1.0)) # Yellow
mat_trunk   = create_mat("M_Trunk",   (0.2, 0.8, 0.2, 1.0)) # Green
mat_fl      = create_mat("M_FL",      (0.2, 0.4, 1.0, 1.0)) # Blue
mat_fr      = create_mat("M_FR",      (0.2, 0.8, 1.0, 1.0)) # Cyan
mat_rl      = create_mat("M_RL",      (1.0, 0.2, 0.5, 1.0)) # Pink / Magenta
mat_rr      = create_mat("M_RR",      (1.0, 0.5, 0.1, 1.0)) # Orange
mat_cand2   = create_mat("M_Cand2",   (0.6, 0.1, 0.8, 1.0)) # Purple for faces 27 & 64

obj.data.materials.clear()
for m in [mat_chassis, mat_hood, mat_trunk, mat_fl, mat_fr, mat_rl, mat_rr, mat_cand2]:
    obj.data.materials.append(m)

# Assign chassis (0) to all
for p in mesh.polygons:
    p.material_index = 0

# Hood: {20, 39, 117, 136} -> mat 1
for fi in [20, 39, 117, 136]:
    mesh.polygons[fi].material_index = 1

# Trunk: {12, 44, 109, 141} -> mat 2
for fi in [12, 44, 109, 141]:
    mesh.polygons[fi].material_index = 2

# FL: [17, 19, 70, 55, 8, 9, 67, 56] -> mat 3
for fi in [17, 19, 70, 55, 8, 9, 67, 56]:
    mesh.polygons[fi].material_index = 3

# FR: [114, 116, 167, 152, 105, 106, 164, 153] -> mat 4
for fi in [114, 116, 167, 152, 105, 106, 164, 153]:
    mesh.polygons[fi].material_index = 4

# RL: [25, 24, 69, 57] -> mat 5
for fi in [25, 24, 69, 57]:
    mesh.polygons[fi].material_index = 5

# RR: [122, 121, 166, 154] -> mat 6
for fi in [122, 121, 166, 154]:
    mesh.polygons[fi].material_index = 6

# Purple candidate: Faces 27 & 64 (left) and 124 & 161 (right) -> mat 7
for fi in [27, 64, 124, 161]:
    mesh.polygons[fi].material_index = 7

# Setup camera with Track To
cam_data = bpy.data.cameras.new("SideCam")
cam_obj = bpy.data.objects.new("SideCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = (3.5, -0.2, 0.5)
const = cam_obj.constraints.new(type='TRACK_TO')
const.target = obj
const.track_axis = 'TRACK_NEGATIVE_Z'
const.up_axis = 'UP_Y'

# Light
light_data = bpy.data.lights.new(name="Sun2", type='SUN')
light_data.energy = 4.0
light_obj = bpy.data.objects.new(name="Sun2", object_data=light_data)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(45), math.radians(30), math.radians(45))

bpy.context.scene.render.resolution_x = 1000
bpy.context.scene.render.resolution_y = 500
bpy.context.scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\render_side_color_analysis.png"
bpy.ops.render.render(write_still=True)
print("Rendered side color analysis!")
