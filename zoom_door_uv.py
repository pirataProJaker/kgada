import bpy

# Load uv_texture_overlay.png, crop the door region and save it
# In Blender, we can render just that region with Ortho camera zoomed in!

bpy.ops.wm.read_factory_settings(use_empty=True)

# 1. Load uv_texture_overlay.png as an image texture on a plane
plane_mesh = bpy.data.meshes.new("CropPlane")
plane_obj = bpy.data.objects.new("CropPlane", plane_mesh)
bpy.context.scene.collection.objects.link(plane_obj)

import bmesh
bm = bmesh.new()
v0 = bm.verts.new((0.0, 0.0, 0.0))
v1 = bm.verts.new((1.0, 0.0, 0.0))
v2 = bm.verts.new((1.0, 1.0, 0.0))
v3 = bm.verts.new((0.0, 1.0, 0.0))
f = bm.faces.new((v0, v1, v2, v3))
uv_l = bm.loops.layers.uv.verify()
f.loops[0][uv_l].uv = (0.0, 0.0)
f.loops[1][uv_l].uv = (1.0, 0.0)
f.loops[2][uv_l].uv = (1.0, 1.0)
f.loops[3][uv_l].uv = (0.0, 1.0)
bm.to_mesh(plane_mesh)
bm.free()

tex_img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\uv_texture_overlay.png")
mat = bpy.data.materials.new("MatCrop")
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tex_node = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex_node.image = tex_img
tex_node.interpolation = 'Closest'
mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Emission Color'])
bsdf.inputs['Emission Strength'].default_value = 1.0
plane_obj.data.materials.append(mat)

# Zoom into the side of the car:
# U in [0.20, 0.85] -> Center U = 0.525, Width = 0.65
# V in [0.55, 0.90] -> Center V = 0.725, Height = 0.35
cam_data = bpy.data.cameras.new("ZoomCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 0.65
cam_obj = bpy.data.objects.new("ZoomCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = (0.525, 0.725, 2.0)
cam_obj.rotation_euler = (0.0, 0.0, 0.0)

scene = bpy.context.scene
scene.render.resolution_x = 1200
scene.render.resolution_y = 600
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\door_uv_zoomed.png"

bpy.ops.render.render(write_still=True)
print("Rendered door_uv_zoomed.png!")
