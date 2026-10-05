import bpy

# Load Suspicious Car.blend
bpy.ops.wm.read_factory_settings(use_empty=True)
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
bpy.ops.wm.open_mainfile(filepath=blend_path)

obj = bpy.data.objects['Body']
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')

# Export UV layout to an image
uv_layout_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\uv_layout_overlay.png"
bpy.ops.uv.export_layout(filepath=uv_layout_path, size=(1024, 1024), opacity=0.8)

bpy.ops.object.mode_set(mode='OBJECT')
print("Exported UV layout overlay!")
