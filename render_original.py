import bpy

# Set up render settings
bpy.context.scene.render.resolution_x = 800
bpy.context.scene.render.resolution_y = 600
bpy.context.scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\render_original_raw.png"

# Setup camera
cam_data = bpy.data.cameras.new("CheckCam")
cam_obj = bpy.data.objects.new("CheckCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = (-3.5, -4.5, 2.5)
import math
cam_obj.rotation_euler = (math.radians(65), 0, math.radians(-35))

# Light
light_data = bpy.data.lights.new(name="Sun", type='SUN')
light_data.energy = 3.0
light_obj = bpy.data.objects.new(name="Sun", object_data=light_data)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(45), math.radians(30), math.radians(45))

bpy.ops.render.render(write_still=True)
print("Rendered original raw!")
