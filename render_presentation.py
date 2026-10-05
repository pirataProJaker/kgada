import bpy
import math
from mathutils import Vector, Euler

# Open sedan_modular.blend
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.open_mainfile(filepath=blend_path)

scene = bpy.context.scene
scene.render.resolution_x = 1280
scene.render.resolution_y = 720

# Enable two-sided materials so inner side of doors and hood are shaded
for mat in bpy.data.materials:
    mat.use_backface_culling = False
    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                node.interpolation = 'Closest'

# Lighting: Key, Fill, Rim, Top
def add_sun(name, energy, rot):
    light = bpy.data.lights.new(name=name, type='SUN')
    light.energy = energy
    obj = bpy.data.objects.new(name=name, object_data=light)
    scene.collection.objects.link(obj)
    obj.rotation_euler = rot
    return obj

# Remove existing lights
for o in [o for o in scene.objects if o.type == 'LIGHT']:
    bpy.data.objects.remove(o, do_unlink=True)

add_sun("SunKey",  3.0, (math.radians(45), math.radians(15), math.radians(-35)))
add_sun("SunFill", 2.2, (math.radians(35), math.radians(-30), math.radians(145)))
add_sun("SunRim",  1.8, (math.radians(-25), math.radians(20), math.radians(80)))
add_sun("SunTop",  1.5, (math.radians(85), 0, 0))

# Objects reference
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

all_parts = [hood, trunk, door_fl, door_fr, door_rl, door_rr, w_fl, w_fr, w_rl, w_rr]
rest_transforms = {obj.name: (Vector(obj.location), Euler(obj.rotation_euler)) for obj in all_parts if obj}

def reset():
    for o in all_parts:
        if o and o.name in rest_transforms:
            loc, rot = rest_transforms[o.name]
            o.location = Vector(loc)
            o.rotation_euler = Euler(rot)

# Camera setup
cam_data = bpy.data.cameras.new("Cam")
cam_obj = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

def point_cam(loc, target=Vector((0.0, 0.0, 0.6))):
    cam_obj.location = loc
    d = target - loc
    cam_obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()

# -------------------------------------------------------------
# 1. RENDER CLOSED VEHICLE (100% seamless)
# -------------------------------------------------------------
reset()
point_cam(Vector((-5.0, 4.0, 2.6)))
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\separacion_1_cerrado.png"
bpy.ops.render.render(write_still=True)
print("Saved separacion_1_cerrado.png")

# -------------------------------------------------------------
# 2. RENDER OPEN DOORS & HOOD (realistic hinges)
# -------------------------------------------------------------
reset()
if hood:    hood.rotation_euler.x = math.radians(-48)
if trunk:   trunk.rotation_euler.x = math.radians(50)
if door_fl: door_fl.rotation_euler.z = math.radians(-58)
if door_fr: door_fr.rotation_euler.z = math.radians(58)
if door_rl: door_rl.rotation_euler.z = math.radians(-54)
if door_rr: door_rr.rotation_euler.z = math.radians(54)

point_cam(Vector((-4.8, 3.8, 2.5)))
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\separacion_2_abierto.png"
bpy.ops.render.render(write_still=True)
print("Saved separacion_2_abierto.png")

# -------------------------------------------------------------
# 3. RENDER EXPLODED VIEW (DESPIECE MODULAR COMPLETO)
# -------------------------------------------------------------
reset()
# Lift hood & trunk
if hood:    hood.location += Vector((0.0, 1.2, 0.6))
if trunk:   trunk.location += Vector((0.0, -1.2, 0.6))
# Separate doors outward
if door_fl: door_fl.location += Vector((-1.1, 0.0, 0.15))
if door_fr: door_fr.location += Vector(( 1.1, 0.0, 0.15))
if door_rl: door_rl.location += Vector((-1.1, 0.0, 0.15))
if door_rr: door_rr.location += Vector(( 1.1, 0.0, 0.15))
# Separate wheels outward
if w_fl:    w_fl.location += Vector((-0.8, 0.0, 0.0))
if w_fr:    w_fr.location += Vector(( 0.8, 0.0, 0.0))
if w_rl:    w_rl.location += Vector((-0.8, 0.0, 0.0))
if w_rr:    w_rr.location += Vector(( 0.8, 0.0, 0.0))

point_cam(Vector((-6.0, 5.0, 4.2)), target=Vector((0.0, 0.0, 0.8)))
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\separacion_3_despiece.png"
bpy.ops.render.render(write_still=True)
print("Saved separacion_3_despiece.png")

# -------------------------------------------------------------
# 4. RENDER EXPLODED VIEW FRONT ANGLE (Front 3/4)
# -------------------------------------------------------------
point_cam(Vector((-5.5, -4.5, 3.8)), target=Vector((0.0, 0.0, 0.8)))
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\separacion_4_despiece_trasero.png"
bpy.ops.render.render(write_still=True)
print("Saved separacion_4_despiece_trasero.png")
