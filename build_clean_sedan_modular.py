import bpy
import bmesh
from mathutils import Vector, Matrix
import math
import os
import shutil

bpy.ops.wm.read_factory_settings(use_empty=True)

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = data_from.objects
    data_to.materials = data_from.materials
    data_to.images = data_from.images

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

tex_white_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png"
tex_img = bpy.data.images.load(tex_white_path, check_existing=True)

for mat in bpy.data.materials:
    mat.use_backface_culling = False
    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                node.image = tex_img
                node.interpolation = 'Closest'

body = bpy.data.objects['Body']
mesh = body.data

# 1. Map symmetry across X = 0
sym_map = {}
for i, p1 in enumerate(mesh.polygons):
    if p1.center.x > 0.05:
        target = (-p1.center.x, p1.center.y, p1.center.z)
        best_j = -1
        best_dist = 999.0
        for j, p2 in enumerate(mesh.polygons):
            if p2.center.x < -0.05:
                d = (p2.center.x - target[0])**2 + (p2.center.y - target[1])**2 + (p2.center.z - target[2])**2
                if d < best_dist:
                    best_dist = d
                    best_j = j
        if best_dist < 0.001:
            sym_map[i] = best_j

# 2. BMesh Bisect ONLY on Front Cowl at Y = -0.653
# Rear door has a natural, solid, continuous manifold edge loop [9, 11, 60, 52, 10]
# So rear door does NOT need destructive bisects that tear holes in the mesh!
bm = bmesh.new()
bm.from_mesh(mesh)

left_front_faces = [f for f in bm.faces if f.index in [17, 19, 70]]
right_front_faces = [f for f in bm.faces if f.index in [sym_map[17], sym_map[19], sym_map[70]]]
front_geom = list(set([v for f in (left_front_faces + right_front_faces) for v in f.verts] +
                      [e for f in (left_front_faces + right_front_faces) for e in f.edges] +
                      left_front_faces + right_front_faces))
bmesh.ops.bisect_plane(
    bm,
    geom=front_geom,
    plane_co=Vector((0.0, -0.653, 0.3)),
    plane_no=Vector((0.0, 1.0, 0.0))
)

bm.to_mesh(mesh)
bm.free()

# 3. Classify Faces into Modular Components
faces_hood = {20, 39, 117, 136}
faces_trunk = {12, 44, 109, 141}
faces_fl = set()
faces_fr = set()
faces_rl = {25, 24, 69, 57}
faces_rr = {sym_map[25], sym_map[24], sym_map[69], sym_map[57]}

for f in mesh.polygons:
    cents = f.center
    vcos = [mesh.vertices[vi].co for vi in f.vertices]
    
    # Left Front Door:
    if all(v.x > 0.20 for v in vcos) and f.normal.x > 0.3:
        if min(v.y for v in vcos) >= -0.654 and max(v.y for v in vcos) <= 0.012:
            if max(v.z for v in vcos) <= 0.835:
                faces_fl.add(f.index)

    # Right Front Door:
    if all(v.x < -0.20 for v in vcos) and f.normal.x < -0.3:
        if min(v.y for v in vcos) >= -0.654 and max(v.y for v in vcos) <= 0.012:
            if max(v.z for v in vcos) <= 0.835:
                faces_fr.add(f.index)

print(f"Parts Face Counts:")
print(f"  Hood: {len(faces_hood)}")
print(f"  Trunk: {len(faces_trunk)}")
print(f"  Door FL: {len(faces_fl)}")
print(f"  Door FR: {len(faces_fr)}")
print(f"  Door RL: {len(faces_rl)}")
print(f"  Door RR: {len(faces_rr)}")

all_movable = faces_hood | faces_trunk | faces_fl | faces_fr | faces_rl | faces_rr
chassis_faces = set(range(len(mesh.polygons))) - all_movable
print(f"  Chassis: {len(chassis_faces)}")

# 4. Extract Parts with Accurate Hinge Pivots
def extract_part(src_obj, face_indices, part_name, pivot_point):
    bm = bmesh.new()
    bm.from_mesh(src_obj.data)
    faces_to_del = [f for f in bm.faces if f.index not in face_indices]
    bmesh.ops.delete(bm, geom=faces_to_del, context='FACES_ONLY')
    verts_to_del = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=verts_to_del, context='VERTS')
    
    bmesh.ops.translate(bm, vec=-pivot_point, verts=bm.verts)
    
    mesh_new = bpy.data.meshes.new(part_name)
    bm.to_mesh(mesh_new)
    bm.free()
    
    obj_new = bpy.data.objects.new(part_name, mesh_new)
    obj_new.location = pivot_point
    for m in src_obj.data.materials:
        obj_new.data.materials.append(m)
    bpy.context.scene.collection.objects.link(obj_new)
    return obj_new

fl_obj = extract_part(body, faces_fl, "Part_Door_FL", Vector((0.488, -0.653, 0.340)))
fr_obj = extract_part(body, faces_fr, "Part_Door_FR", Vector((-0.488, -0.653, 0.340)))
rl_obj = extract_part(body, faces_rl, "Part_Door_RL", Vector((0.490, 0.011, 0.340)))
rr_obj = extract_part(body, faces_rr, "Part_Door_RR", Vector((-0.490, 0.011, 0.340)))

hood_obj = extract_part(body, faces_hood, "Part_Hood", Vector((0.0, -0.653, 0.545)))
trunk_obj = extract_part(body, faces_trunk, "Part_Trunk", Vector((0.0, 0.865, 0.572)))
chassis_obj = extract_part(body, chassis_faces, "Chassis", Vector((0.0, 0.0, 0.0)))

bpy.data.objects.remove(body, do_unlink=True)

# Standardize Wheels
for wname in ['Wheel.FL', 'Wheel.FR', 'Wheel.RL', 'Wheel.RR']:
    if wname in bpy.data.objects:
        w_obj = bpy.data.objects[wname]
        w_obj.name = "Part_" + wname.replace(".", "_")

out_dir = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s"

# Save .blend
blend_save_path = os.path.join(out_dir, "sedan_modular.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_save_path)
print(f"Saved {blend_save_path}")

# Export .glb
glb_save_path = os.path.join(out_dir, "sedan_modular.glb")
bpy.ops.export_scene.gltf(
    filepath=glb_save_path,
    export_format='GLB',
    use_selection=False,
    export_materials='EXPORT',
    export_apply=False
)
print(f"Exported {glb_save_path}")

# ================= HIGH RESOLUTION PRESENTATION RENDERS =================
light = bpy.data.lights.new(name="Sun", type='SUN')
light.energy = 3.5
light_obj = bpy.data.objects.new(name="Sun", object_data=light)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(60), math.radians(20), math.radians(45))

fill_light = bpy.data.lights.new(name="Fill", type='SUN')
fill_light.energy = 1.2
fill_obj = bpy.data.objects.new(name="Fill", object_data=fill_light)
bpy.context.scene.collection.objects.link(fill_obj)
fill_obj.rotation_euler = (math.radians(-45), math.radians(-30), math.radians(120))

cam_data = bpy.data.cameras.new("RenderCam")
cam_obj = bpy.data.objects.new("RenderCam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

scene = bpy.context.scene
scene.render.resolution_x = 1600
scene.render.resolution_y = 900

# Render 1: Profile View Closed
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 3.3
cam_obj.location = (3.5, 0.0, 0.45)
cam_obj.rotation_euler = (math.radians(90), 0, math.radians(90))

scene.render.filepath = os.path.join(out_dir, "presentacion_1_cerrado_perfil.png")
bpy.ops.render.render(write_still=True)
print("Rendered presentacion_1_cerrado_perfil.png")

# Render 2: Open Doors Perspective (Doors open OUTWARDS, Hood opens UP, Trunk opens UP)
cam_data.type = 'PERSP'
cam_data.lens = 42
cam_obj.location = (3.2, -2.6, 1.6)
cam_obj.rotation_euler = (math.radians(68), 0, math.radians(52))

fl_obj.rotation_euler = (0, 0, math.radians(-55))
fr_obj.rotation_euler = (0, 0, math.radians(55))
rl_obj.rotation_euler = (0, 0, math.radians(-55))
rr_obj.rotation_euler = (0, 0, math.radians(55))
hood_obj.rotation_euler = (math.radians(-45), 0, 0)
trunk_obj.rotation_euler = (math.radians(45), 0, 0)

scene.render.filepath = os.path.join(out_dir, "presentacion_2_puertas_abiertas.png")
bpy.ops.render.render(write_still=True)
print("Rendered presentacion_2_puertas_abiertas.png")

# Render 3: Exploded Front-Left Isometric View
fl_obj.rotation_euler = (0, 0, 0)
fr_obj.rotation_euler = (0, 0, 0)
rl_obj.rotation_euler = (0, 0, 0)
rr_obj.rotation_euler = (0, 0, 0)
hood_obj.rotation_euler = (0, 0, 0)
trunk_obj.rotation_euler = (0, 0, 0)

fl_obj.location += Vector((0.50, 0.0, 0.0))
fr_obj.location += Vector((-0.50, 0.0, 0.0))
rl_obj.location += Vector((0.50, 0.0, 0.0))
rr_obj.location += Vector((-0.50, 0.0, 0.0))
hood_obj.location += Vector((0.0, -0.50, 0.35))
trunk_obj.location += Vector((0.0, 0.50, 0.35))

for wname in ['Part_Wheel_FL', 'Part_Wheel_FR', 'Part_Wheel_RL', 'Part_Wheel_RR']:
    if wname in bpy.data.objects:
        w_obj = bpy.data.objects[wname]
        sign = 1.0 if 'L' in wname else -1.0
        w_obj.location += Vector((sign * 0.35, 0.0, 0.0))

cam_obj.location = (3.4, -2.8, 2.0)
cam_obj.rotation_euler = (math.radians(65), 0, math.radians(50))

scene.render.filepath = os.path.join(out_dir, "presentacion_3_despiece.png")
bpy.ops.render.render(write_still=True)
print("Rendered presentacion_3_despiece.png")

# Render 4: Exploded Rear-Left Isometric View
cam_obj.location = (3.4, 2.8, 1.8)
cam_obj.rotation_euler = (math.radians(68), 0, math.radians(130))

scene.render.filepath = os.path.join(out_dir, "presentacion_4_despiece_trasero.png")
bpy.ops.render.render(write_still=True)
print("Rendered presentacion_4_despiece_trasero.png")

# Copy presentation renders to D:\descargas
descargas_dir = r"D:\descargas"
if os.path.exists(descargas_dir):
    for f in ["presentacion_1_cerrado_perfil.png", "presentacion_2_puertas_abiertas.png", "presentacion_3_despiece.png", "presentacion_4_despiece_trasero.png"]:
        shutil.copy2(os.path.join(out_dir, f), os.path.join(descargas_dir, f))
        print(f"Copied {f} to D:\\descargas")
