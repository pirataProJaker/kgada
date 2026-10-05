import bpy
import math
from mathutils import Vector, Euler

# Open the newly separated sedan_modular.blend
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.open_mainfile(filepath=blend_path)

# Set resolution and Eevee settings
scene = bpy.context.scene
scene.render.resolution_x = 1200
scene.render.resolution_y = 800

# Setup 3-point lighting
light_key = bpy.data.lights.new(name="LightKey", type='SUN')
light_key.energy = 3.5
light_key_obj = bpy.data.objects.new(name="LightKey", object_data=light_key)
scene.collection.objects.link(light_key_obj)
light_key_obj.rotation_euler = (math.radians(50), math.radians(20), math.radians(-40))

light_fill = bpy.data.lights.new(name="LightFill", type='SUN')
light_fill.energy = 1.8
light_fill_obj = bpy.data.objects.new(name="LightFill", object_data=light_fill)
scene.collection.objects.link(light_fill_obj)
light_fill_obj.rotation_euler = (math.radians(30), math.radians(-30), math.radians(140))

# Ground plane
mesh_ground = bpy.data.meshes.new("GroundPlane")
ground_obj = bpy.data.objects.new("GroundPlane", mesh_ground)
scene.collection.objects.link(ground_obj)
import bmesh
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=15)
bm.to_mesh(mesh_ground)
bm.free()
ground_obj.location.z = 0.0

mat_ground = bpy.data.materials.new(name="M_Ground")
mat_ground.use_nodes = True
bsdf = mat_ground.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs['Base Color'].default_value = (0.22, 0.23, 0.26, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.8
ground_obj.data.materials.append(mat_ground)

# Camera
cam_data = bpy.data.cameras.new("MainCam")
cam_obj = bpy.data.objects.new("MainCam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

cam_obj.location = (-5.5, 4.2, 3.2)
# Look at center of car (0, 0, 0.7)
target = Vector((0.0, 0.0, 0.7))
direction = target - cam_obj.location
rot_quat = direction.to_track_quat('-Z', 'Y')
cam_obj.rotation_euler = rot_quat.to_euler()

# Objects reference
hood = bpy.data.objects.get("Part_Hood")
trunk = bpy.data.objects.get("Part_Trunk")
door_fl = bpy.data.objects.get("Part_Door_FL")
door_fr = bpy.data.objects.get("Part_Door_FR")
door_rl = bpy.data.objects.get("Part_Door_RL")
door_rr = bpy.data.objects.get("Part_Door_RR")
w_fl = bpy.data.objects.get("Part_Wheel_FL")
w_fr = bpy.data.objects.get("Part_Wheel_FR")
w_rl = bpy.data.objects.get("Part_Wheel_RL")
w_rr = bpy.data.objects.get("Part_Wheel_RR")

# Store original rest transforms
rest_transforms = {}
for obj in [hood, trunk, door_fl, door_fr, door_rl, door_rr, w_fl, w_fr, w_rl, w_rr]:
    if obj:
        rest_transforms[obj.name] = (Vector(obj.location), Euler(obj.rotation_euler))

def restore_rest():
    for name, (loc, rot) in rest_transforms.items():
        o = bpy.data.objects.get(name)
        if o:
            o.location = Vector(loc)
            o.rotation_euler = Euler(rot)

# --- 1. RENDER CLOSED ---
restore_rest()
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\proof_1_closed.png"
bpy.ops.render.render(write_still=True)
print("Rendered proof_1_closed.png")

# --- 2. RENDER OPEN (HINGES) ---
restore_rest()
if hood:
    hood.rotation_euler.x = math.radians(-48) # Hood opens forward/up
if trunk:
    trunk.rotation_euler.x = math.radians(50)  # Trunk opens backward/up
if door_fl:
    door_fl.rotation_euler.z = math.radians(-62) # FL opens outward
if door_fr:
    door_fr.rotation_euler.z = math.radians(62)  # FR opens outward
if door_rl:
    door_rl.rotation_euler.z = math.radians(-58) # RL opens outward
if door_rr:
    door_rr.rotation_euler.z = math.radians(58)  # RR opens outward

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\proof_2_open_hinges.png"
bpy.ops.render.render(write_still=True)
print("Rendered proof_2_open_hinges.png")

# --- 3. RENDER EXPLODED VIEW ---
restore_rest()
if hood:
    hood.location += Vector((0.0, 0.8, 0.5))
if trunk:
    trunk.location += Vector((0.0, -0.8, 0.5))
if door_fl:
    door_fl.location += Vector((-0.6, 0.0, 0.1))
if door_fr:
    door_fr.location += Vector((0.6, 0.0, 0.1))
if door_rl:
    door_rl.location += Vector((-0.6, 0.0, 0.1))
if door_rr:
    door_rr.location += Vector((0.6, 0.0, 0.1))
if w_fl:
    w_fl.location += Vector((-0.5, 0.0, 0.0))
if w_fr:
    w_fr.location += Vector((0.5, 0.0, 0.0))
if w_rl:
    w_rl.location += Vector((-0.5, 0.0, 0.0))
if w_rr:
    w_rr.location += Vector((0.5, 0.0, 0.0))

scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\proof_3_exploded_view.png"
bpy.ops.render.render(write_still=True)
print("Rendered proof_3_exploded_view.png")

# Also render exploded view from higher isometric angle
cam_obj.location = (-6.5, 5.0, 4.5)
direction = target - cam_obj.location
rot_quat = direction.to_track_quat('-Z', 'Y')
cam_obj.rotation_euler = rot_quat.to_euler()
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\proof_4_exploded_high.png"
bpy.ops.render.render(write_still=True)
print("Rendered proof_4_exploded_high.png")
