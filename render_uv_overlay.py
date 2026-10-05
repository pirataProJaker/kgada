import bpy
import bmesh
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)

# 1. Load Suspicious Car.blend Body UVs
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

body = bpy.data.objects['Body']
mesh = body.data
uv_layer = mesh.uv_layers.active.data

# Store UV faces and loop UVs
uv_faces = []
for p in mesh.polygons:
    coords = [uv_layer[li].uv for li in p.loop_indices]
    uv_faces.append((p.index, coords))

# Remove 3D body
bpy.data.objects.remove(body, do_unlink=True)

# 2. Create Background Plane for Texture White.png
plane_mesh = bpy.data.meshes.new("TexPlane")
plane_obj = bpy.data.objects.new("TexPlane", plane_mesh)
bpy.context.scene.collection.objects.link(plane_obj)

bm = bmesh.new()
v0 = bm.verts.new((0.0, 0.0, 0.0))
v1 = bm.verts.new((1.0, 0.0, 0.0))
v2 = bm.verts.new((1.0, 1.0, 0.0))
v3 = bm.verts.new((0.0, 1.0, 0.0))
f = bm.faces.new((v0, v1, v2, v3))
uv_l = bm.loops.layers.uv.verify()
f.loops[0][uv_l].uv = Vector((0.0, 0.0))
f.loops[1][uv_l].uv = Vector((1.0, 0.0))
f.loops[2][uv_l].uv = Vector((1.0, 1.0))
f.loops[3][uv_l].uv = Vector((0.0, 1.0))
bm.to_mesh(plane_mesh)
bm.free()

tex_img = bpy.data.images.load(r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png")
mat_tex = bpy.data.materials.new("MatTex")
mat_tex.use_nodes = True
bsdf = next(n for n in mat_tex.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tex_node = mat_tex.node_tree.nodes.new('ShaderNodeTexImage')
tex_node.image = tex_img
tex_node.interpolation = 'Closest'
mat_tex.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
mat_tex.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Emission Color'])
bsdf.inputs['Emission Strength'].default_value = 1.0
plane_obj.data.materials.append(mat_tex)

# 3. Create UV Wireframe overlay
curve_data = bpy.data.curves.new('UVCurves', type='CURVE')
curve_data.dimensions = '3D'
curve_data.bevel_depth = 0.0015

def add_wire_poly(coords):
    spline = curve_data.splines.new('POLY')
    spline.points.add(len(coords))
    for i, uv in enumerate(coords):
        spline.points[i].co = (uv.x, uv.y, 0.01, 1.0)
    spline.points[len(coords)].co = (coords[0].x, coords[0].y, 0.01, 1.0)

curve_obj = bpy.data.objects.new('UVCurves', curve_data)
bpy.context.scene.collection.objects.link(curve_obj)

mat_wire = bpy.data.materials.new("MatWire")
mat_wire.use_nodes = True
bsdf_w = next(n for n in mat_wire.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf_w.inputs['Base Color'].default_value = (1.0, 0.0, 0.0, 1.0)
bsdf_w.inputs['Emission Color'].default_value = (1.0, 0.0, 0.0, 1.0)
bsdf_w.inputs['Emission Strength'].default_value = 2.0
curve_obj.data.materials.append(mat_wire)

for idx, coords in uv_faces:
    add_wire_poly(coords)

# 4. Orthographic Camera pointing down at (0.5, 0.5)
cam_data = bpy.data.cameras.new("OrthoCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 1.0
cam_obj = bpy.data.objects.new("OrthoCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

cam_obj.location = (0.5, 0.5, 2.0)
cam_obj.rotation_euler = (0.0, 0.0, 0.0)

scene = bpy.context.scene
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.filepath = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\uv_texture_overlay.png"

bpy.ops.render.render(write_still=True)
print("Rendered uv_texture_overlay.png successfully!")
