import bpy
import math

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=blend_path)

rl = bpy.data.objects['Part_Door_RL']
chassis = bpy.data.objects['Chassis']

# Camera
cam_data = bpy.data.cameras.new("DbgCam")
cam = bpy.data.objects.new("DbgCam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

# Light
light = bpy.data.lights.new(name="Sun", type='SUN')
light.energy = 3.5
light_obj = bpy.data.objects.new(name="Sun", object_data=light)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(60), math.radians(20), math.radians(45))

# Hide everything except Part_Door_RL
for obj in bpy.data.objects:
    if obj not in [rl, cam, light_obj]:
        obj.hide_render = True

rl.hide_render = False
rl.rotation_euler = (0, 0, 0)

# Camera looking at rear door from rear-3/4 angle
cam.location = (2.2, 1.2, 0.8)
cam.rotation_euler = (math.radians(70), 0.0, math.radians(115))

scene = bpy.context.scene
scene.render.resolution_x = 1000
scene.render.resolution_y = 700
scene.render.filepath = r"c:\Users\PC 1\PSX\debug_rl_isolated.png"
bpy.ops.render.render(write_still=True)
print("Rendered debug_rl_isolated.png")

# Now hide RL, show Chassis around rear door opening
rl.hide_render = True
chassis.hide_render = False

scene.render.filepath = r"c:\Users\PC 1\PSX\debug_chassis_opening.png"
bpy.ops.render.render(write_still=True)
print("Rendered debug_chassis_opening.png")
