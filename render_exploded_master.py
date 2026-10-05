import bpy
import math
from mathutils import Vector, Euler

# Open sedan_modular.blend
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.open_mainfile(filepath=blend_path)

scene = bpy.context.scene
scene.render.resolution_x = 1280
scene.render.resolution_y = 720

for mat in bpy.data.materials:
    mat.use_backface_culling = False
    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                node.interpolation = 'Closest'

# Remove existing lights
for o in [o for o in scene.objects if o.type == 'LIGHT']:
    bpy.data.objects.remove(o, do_unlink=True)

def add_sun(name, energy, rot):
    light = bpy.data.lights.new(name=name, type='SUN')
    light.energy = energy
    obj = bpy.data.objects.new(name=name, object_data=light)
    scene.collection.objects.link(obj)
    obj.rotation_euler = rot
    return obj

add_sun("Sun1", 3.2, (math.radians(50), math.radians(20), math.radians(-30)))
add_sun("Sun2", 2.2, (math.radians(40), math.radians(-30), math.radians(150)))
add_sun("Sun3", 1.8, (math.radians(80), 0, 0))
add_sun("Sun4", 1.5, (math.radians(-30), math.radians(30), math.radians(-120)))

# Ground
mesh_ground = bpy.data.meshes.new("GroundPlane")
ground_obj = bpy.data.objects.new("GroundPlane", mesh_ground)
scene.collection.objects.link(ground_obj)
import bmesh
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=20)
bm.to_mesh(mesh_ground)
bm.free()
ground_obj.location.z = 0.0

mat_ground = bpy.data.materials.new(name="M_Ground")
mat_ground.use_nodes = True
bsdf = mat_ground.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs['Base Color'].default_value = (0.16, 0.17, 0.20, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.9
ground_obj.data.materials.append(mat_ground)

hood    = bpy.data.objects.get("Part_Hood")
trunk   = bpy.data.objects.get("Part_Trunk")
door_fl = bpy.data.objects.get("Part_Door_FL")
door_fr = bpy.data.objects.get("Part_Door_FR")
door_rl = bpy.data.objects.get("Part_Door_RL")
door_rr = bpy.data.objects.get("Part_Door_RR")
w_fl    = bpy.data.objects.get("Part_Wheel_FL")
w_fr    = bpy.data.objects.get("Part_Wheel_FR")
w_rl    = bpy.data.objects.get("Part_Wheel_RL")
w_rr    = bpy.data.objects.get("Part_Wheel_RR")
chassis = bpy.data.objects.get("Chassis")

# Camera Orthographic
cam_data = bpy.data.cameras.new("IsoCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 9.2
cam_obj = bpy.data.objects.new("IsoCam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

# Displace each piece to its own distinct coordinate in 3D space:
if hood:    hood.location    += Vector(( 0.0,  1.8,  1.1))
if trunk:   trunk.location   += Vector(( 0.0, -1.8,  1.1))

# Displace front doors outward AND slightly forward
if door_fl: door_fl.location += Vector((-1.8,  0.4,  0.4))
if door_fr: door_fr.location += Vector(( 1.8,  0.4,  0.4))

# Displace rear doors outward AND slightly backward
if door_rl: door_rl.location += Vector((-1.8, -0.5,  0.4))
if door_rr: door_rr.location += Vector(( 1.8, -0.5,  0.4))

# Displace wheels outward
if w_fl:    w_fl.location    += Vector((-1.3,  0.3,  0.0))
if w_fr:    w_fr.location    += Vector(( 1.3,  0.3,  0.0))
if w_rl:    w_rl.location    += Vector((-1.3, -0.3,  0.0))
if w_rr:    w_rr.location    += Vector(( 1.3, -0.3,  0.0))

# View 1: Isometric Front-Left (Front is +Y, Left is -X)
target = Vector((0.0, 0.0, 0.8))
cam_obj.location = Vector((-8.0, 8.0, 6.0))
cam_obj.rotation_euler = (target - cam_obj.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\despiece_master_front.png"
bpy.ops.render.render(write_still=True)
print("Rendered despiece_master_front.png")

# View 2: Isometric Rear-Right (Rear is -Y, Right is +X)
cam_obj.location = Vector((8.0, -8.0, 6.0))
cam_obj.rotation_euler = (target - cam_obj.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\despiece_master_rear.png"
bpy.ops.render.render(write_still=True)
print("Rendered despiece_master_rear.png")
