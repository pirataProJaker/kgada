import bpy

# Load the user-marked image and render a high-res crop of the rear door area
bpy.ops.wm.read_factory_settings(use_empty=True)

plane_mesh = bpy.data.meshes.new("UserCropPlane")
plane_obj = bpy.data.objects.new("UserCropPlane", plane_mesh)
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

img = bpy.data.images.load(r"c:\Users\PC 1\PSX\guia_corte_marcada_usuario.png")
mat = bpy.data.materials.new("MatCrop")
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tex_node = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex_node.image = img
tex_node.interpolation = 'Closest'
mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Emission Color'])
bsdf.inputs['Emission Strength'].default_value = 1.0
plane_obj.data.materials.append(mat)

# Zoom into rear door:
# X in [0.45, 0.85] -> Center = 0.65, Width = 0.40
# Y in [0.20, 0.90] -> Center = 0.55, Height = 0.70
cam_data = bpy.data.cameras.new("ZoomCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 0.45
cam_obj = bpy.data.objects.new("ZoomCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = (0.65, 0.55, 2.0)
cam_obj.rotation_euler = (0.0, 0.0, 0.0)

scene = bpy.context.scene
scene.render.resolution_x = 1200
scene.render.resolution_y = 1000
scene.render.filepath = r"c:\Users\PC 1\PSX\user_rear_door_crop.png"
bpy.ops.render.render(write_still=True)
print("Rendered user_rear_door_crop.png!")
