import bpy
import bmesh
import math
from mathutils import Vector, Matrix

# 1. Clean scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# 2. Open original Suspicious Car.blend
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = data_from.objects
    data_to.materials = data_from.materials
    data_to.images = data_from.images

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

# Ensure Texture White is used
tex_white_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Texture White.png"
tex_img = bpy.data.images.load(tex_white_path, check_existing=True)

# Update materials to use Texture White
for mat in bpy.data.materials:
    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                node.image = tex_img
                # Set interpolation to closest for PSX pixel style
                node.interpolation = 'Closest'

orig_body = bpy.data.objects['Body']

# Symmetrical Face definitions in original mesh:
# Front is -Y, Left is +X in original
faces_hood = {20, 39, 117, 136}
faces_trunk = {12, 44, 109, 141}

faces_door_fl = {17, 19, 70, 55, 8, 9, 67, 56}
faces_door_fr = {114, 116, 167, 152, 105, 106, 164, 153}

faces_door_rl = {25, 24, 69, 57}
faces_door_rr = {122, 121, 166, 154}

modular_defs = {
    "Part_Hood": faces_hood,
    "Part_Trunk": faces_trunk,
    "Part_Door_FL": faces_door_fl,
    "Part_Door_FR": faces_door_fr,
    "Part_Door_RL": faces_door_rl,
    "Part_Door_RR": faces_door_rr,
}

all_separated_faces = set()
for s in modular_defs.values():
    all_separated_faces.update(s)

created_objects = {}

def extract_part(src_obj, face_indices, part_name):
    mesh = src_obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    
    # Delete faces NOT in face_indices
    faces_to_del = [f for f in bm.faces if f.index not in face_indices]
    bmesh.ops.delete(bm, geom=faces_to_del, context='FACES_ONLY')
    
    # Delete unreferenced loose vertices
    verts_to_del = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=verts_to_del, context='VERTS')
    
    new_mesh = bpy.data.meshes.new(part_name)
    bm.to_mesh(new_mesh)
    bm.free()
    
    new_obj = bpy.data.objects.new(part_name, new_mesh)
    for m in src_obj.data.materials:
        new_obj.data.materials.append(m)
        
    bpy.context.scene.collection.objects.link(new_obj)
    return new_obj

# Extract modular parts
for name, f_set in modular_defs.items():
    created_objects[name] = extract_part(orig_body, f_set, name)

# Extract Chassis (everything NOT separated)
chassis_faces = set(range(len(orig_body.data.polygons))) - all_separated_faces
chassis_obj = extract_part(orig_body, chassis_faces, "Chassis")
created_objects["Chassis"] = chassis_obj

# Add recessed engine bay floor and trunk floor to Chassis
bm_ch = bmesh.new()
bm_ch.from_mesh(chassis_obj.data)

# In original coords: Engine bay is around Y in [-1.45, -0.65], X in [-0.45, 0.45], floor Z at 0.16
uv_layer = bm_ch.loops.layers.uv.verify()

v_eb_fl = bm_ch.verts.new(( 0.42, -1.40, 0.16))
v_eb_fr = bm_ch.verts.new((-0.42, -1.40, 0.16))
v_eb_rl = bm_ch.verts.new(( 0.42, -0.65, 0.16))
v_eb_rr = bm_ch.verts.new((-0.42, -0.65, 0.16))

f_eb = bm_ch.faces.new((v_eb_fl, v_eb_rl, v_eb_rr, v_eb_fr))
for l in f_eb.loops:
    l[uv_layer].uv = Vector((0.02, 0.98)) # dark gray / engine bay area in texture

# Trunk floor: Y in [0.85, 1.30], X in [-0.45, 0.45], floor Z at 0.16
v_tr_fl = bm_ch.verts.new(( 0.42,  0.85, 0.16))
v_tr_fr = bm_ch.verts.new((-0.42,  0.85, 0.16))
v_tr_rl = bm_ch.verts.new(( 0.42,  1.30, 0.16))
v_tr_rr = bm_ch.verts.new((-0.42,  1.30, 0.16))

f_tr = bm_ch.faces.new((v_tr_fl, v_tr_rl, v_tr_rr, v_tr_fr))
for l in f_tr.loops:
    l[uv_layer].uv = Vector((0.02, 0.98))

bm_ch.to_mesh(chassis_obj.data)
bm_ch.free()

# Delete original Body
bpy.data.objects.remove(orig_body, do_unlink=True)

# Gather wheels
wheel_objs = {
    "Part_Wheel_FL": bpy.data.objects.get("Wheels_FL"),
    "Part_Wheel_FR": bpy.data.objects.get("Wheel_FR"),
    "Part_Wheel_RL": bpy.data.objects.get("Wheels_RL"),
    "Part_Wheel_RR": bpy.data.objects.get("Wheels_RR"),
}

for name, w_obj in wheel_objs.items():
    if w_obj:
        w_obj.name = name
        created_objects[name] = w_obj

# Scale and Orientation Transformation:
# In Blender, original model had Front = -Y.
# In Godot, standard convention is Front = -Z, Right = +X.
# When Godot imports GLB from Blender: Blender +Y becomes Godot -Z!
# So to make the car face +Y in Blender (so it faces -Z in Godot):
# We rotate 180 degrees around Z axis!
# And scale uniformly by 1.62 to match standard metric Japanese sedan dimensions:
# Length: 4.60m, Width: 1.65m, Height: 1.38m, Wheel Radius: 0.296m.

SCALE_FACTOR = 1.62
rot_mat = Matrix.Rotation(math.radians(180), 4, 'Z')
scale_mat = Matrix.Scale(SCALE_FACTOR, 4)
transform_mat = scale_mat @ rot_mat

all_car_objects = list(created_objects.values())

for obj in all_car_objects:
    # Apply transform to mesh data directly
    obj.data.transform(transform_mat)
    obj.matrix_world = Matrix.Identity(4)

# Set up exact, natural hinge pivots for each part:
def set_object_pivot(obj, pivot_world):
    # Shift vertices relative to pivot, then move object to pivot
    mesh = obj.data
    trans_mesh = Matrix.Translation(-pivot_world)
    mesh.transform(trans_mesh)
    obj.location = pivot_world

# 1. Wheels: center of vertices
for w_name in ["Part_Wheel_FL", "Part_Wheel_FR", "Part_Wheel_RL", "Part_Wheel_RR"]:
    w = created_objects[w_name]
    center = sum([v.co for v in w.data.vertices], Vector()) / len(w.data.vertices)
    set_object_pivot(w, center)

# 2. Part_Hood: pivot at cowl (rear edge of hood)
hood = created_objects["Part_Hood"]
# Rear edge in rotated coords is lowest Y of hood
rear_y = min(v.co.y for v in hood.data.vertices)
pivot_hood = Vector((0.0, rear_y, max(v.co.z for v in hood.data.vertices)))
set_object_pivot(hood, pivot_hood)

# 3. Part_Trunk: pivot at base of rear window (highest Y of trunk in rotated coords)
trunk = created_objects["Part_Trunk"]
front_y = max(v.co.y for v in trunk.data.vertices)
pivot_trunk = Vector((0.0, front_y, max(v.co.z for v in trunk.data.vertices)))
set_object_pivot(trunk, pivot_trunk)

# 4. Front Doors: pivot at front edge (highest Y of front door in rotated coords)
door_fl = created_objects["Part_Door_FL"]
fl_front_y = max(v.co.y for v in door_fl.data.vertices)
fl_x = sum([v.co.x for v in door_fl.data.vertices]) / len(door_fl.data.vertices)
fl_z = sum([v.co.z for v in door_fl.data.vertices]) / len(door_fl.data.vertices)
set_object_pivot(door_fl, Vector((fl_x, fl_front_y, fl_z)))

door_fr = created_objects["Part_Door_FR"]
fr_front_y = max(v.co.y for v in door_fr.data.vertices)
fr_x = sum([v.co.x for v in door_fr.data.vertices]) / len(door_fr.data.vertices)
fr_z = sum([v.co.z for v in door_fr.data.vertices]) / len(door_fr.data.vertices)
set_object_pivot(door_fr, Vector((fr_x, fr_front_y, fr_z)))

# 5. Rear Doors: pivot at B-pillar (highest Y of rear door in rotated coords)
door_rl = created_objects["Part_Door_RL"]
rl_front_y = max(v.co.y for v in door_rl.data.vertices)
rl_x = sum([v.co.x for v in door_rl.data.vertices]) / len(door_rl.data.vertices)
rl_z = sum([v.co.z for v in door_rl.data.vertices]) / len(door_rl.data.vertices)
set_object_pivot(door_rl, Vector((rl_x, rl_front_y, rl_z)))

door_rr = created_objects["Part_Door_RR"]
rr_front_y = max(v.co.y for v in door_rr.data.vertices)
rr_x = sum([v.co.x for v in door_rr.data.vertices]) / len(door_rr.data.vertices)
rr_z = sum([v.co.z for v in door_rr.data.vertices]) / len(door_rr.data.vertices)
set_object_pivot(door_rr, Vector((rr_x, rr_front_y, rr_z)))

# Save clean .blend
blend_out = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print("Saved clean sedan_modular.blend")

# Export GLB for Godot
glb_out = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.glb"
bpy.ops.export_scene.gltf(filepath=glb_out, export_format='GLB', use_selection=False)
print("Exported sedan_modular.glb")

print("\n--- SEPARATION SUMMARY ---")
for name, obj in created_objects.items():
    print(f"{name:15s}: Location=({obj.location.x:7.3f}, {obj.location.y:7.3f}, {obj.location.z:7.3f}) Faces={len(obj.data.polygons):3d}")

