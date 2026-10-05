import bpy
import math
from mathutils import Vector, Euler

# Open sedan_modular.blend
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.open_mainfile(filepath=blend_path)

scene = bpy.context.scene
scene.render.resolution_x = 1280
scene.render.resolution_y = 800

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

add_sun("Sun1", 3.0, (math.radians(50), math.radians(20), math.radians(-30)))
add_sun("Sun2", 2.0, (math.radians(40), math.radians(-30), math.radians(150)))
add_sun("Sun3", 1.5, (math.radians(80), 0, 0))

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

# Camera Orthographic Isometric
cam_data = bpy.data.cameras.new("IsoCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 8.5
cam_obj = bpy.data.objects.new("IsoCam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

# Displace parts for exploded view
if hood:    hood.location    += Vector(( 0.0,  1.5,  0.8))
if trunk:   trunk.location   += Vector(( 0.0, -1.5,  0.8))
if door_fl: door_fl.location += Vector((-1.4,  0.0,  0.3))
if door_fr: door_fr.location += Vector(( 1.4,  0.0,  0.3))
if door_rl: door_rl.location += Vector((-1.4,  0.0,  0.3))
if door_rr: door_rr.location += Vector(( 1.4,  0.0,  0.3))
if w_fl:    w_fl.location    += Vector((-1.0,  0.0,  0.0))
if w_fr:    w_fr.location    += Vector(( 1.0,  0.0,  0.0))
if w_rl:    w_rl.location    += Vector((-1.0,  0.0,  0.0))
if w_rr:    w_rr.location    += Vector(( 1.0,  0.0,  0.0))

# 1. Isometric Front-Left view (Front is +Y, Left is -X)
# Looking from (-10, 10, 8)
cam_obj.location = Vector((-8.0, 8.0, 6.0))
target = Vector((0.0, 0.0, 0.6))
cam_obj.rotation_euler = (target - cam_obj.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\despiece_isometrico_front.png"
bpy.ops.render.render(write_still=True)
print("Rendered despiece_isometrico_front.png")

# 2. Isometric Rear-Right view (Rear is -Y, Right is +X)
cam_obj.location = Vector((8.0, -8.0, 6.0))
cam_obj.rotation_euler = (target - cam_obj.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\despiece_isometrico_rear.png"
bpy.ops.render.render(write_still=True)
print("Rendered despiece_isometrico_rear.png")
