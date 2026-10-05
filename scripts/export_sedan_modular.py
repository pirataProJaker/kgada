import bpy
import bmesh
import math
from mathutils import Vector, Matrix

BLEND_PATH = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
GLB_OUT = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.glb"
BLEND_OUT = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"

bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

# Ensure object mode
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

SCALE = 1.62

body_obj = bpy.data.objects.get("Body")
vano_obj = bpy.data.objects.get("vano_motor")
capo_obj = bpy.data.objects.get("capo")
p_di = bpy.data.objects.get("puerta_DI")
p_dd = bpy.data.objects.get("puerta_DD")
p_ti = bpy.data.objects.get("puerta_TI")
p_td = bpy.data.objects.get("puerta_TD")
w_fr = bpy.data.objects.get("Wheel_FR")
w_fl = bpy.data.objects.get("Wheels_FL")
w_rl = bpy.data.objects.get("Wheels_RL")
w_rr = bpy.data.objects.get("Wheels_RR")

def make_clean_copy(src_obj, new_name):
    new_mesh = src_obj.data.copy()
    new_mesh.name = new_name + "_Mesh"
    new_obj = bpy.data.objects.new(new_name, new_mesh)
    new_obj.matrix_world = src_obj.matrix_world.copy()
    bpy.context.collection.objects.link(new_obj)
    return new_obj

# Copy parts
hood_obj = make_clean_copy(capo_obj, "Part_Hood")
wheel_fl_obj = make_clean_copy(w_fl, "Part_Wheel_FL")
wheel_fr_obj = make_clean_copy(w_fr, "Part_Wheel_FR")
wheel_rl_obj = make_clean_copy(w_rl, "Part_Wheel_RL")
wheel_rr_obj = make_clean_copy(w_rr, "Part_Wheel_RR")

# Combine Body + vano_motor + doors into a single solid Chassis
chassis_mesh = bpy.data.meshes.new("Chassis_Mesh")
bm = bmesh.new()
bm.from_mesh(body_obj.data)
uv_lay = bm.loops.layers.uv.verify()
existing_faces = set(bm.faces)

if vano_obj:
    bm.from_mesh(vano_obj.data)
    new_vano_faces = [f for f in bm.faces if f not in existing_faces]
    for f in new_vano_faces:
        c = f.calc_center_median()
        # Torretas de suspensión y guardabarros interiores al color carrocería / chapa
        if abs(c.x) > 0.25 and c.z > 0.22:
            uv_target = Vector((5.0 / 256.0, 50.0 / 256.0))
        else:
            # Pared de fuego, fondo del vano y carcasas traseras de faros a metal oscuro / aislamiento
            uv_target = Vector((85.0 / 256.0, 250.0 / 256.0))
        for loop in f.loops:
            loop[uv_lay].uv = uv_target

for d in [p_di, p_dd, p_ti, p_td]:
    if d:
        bm.from_mesh(d.data)
bm.to_mesh(chassis_mesh)
bm.free()

chassis_obj = bpy.data.objects.new("Chassis", chassis_mesh)
if body_obj.data.materials:
    for mat in body_obj.data.materials:
        chassis_mesh.materials.append(mat)
bpy.context.collection.objects.link(chassis_obj)

# Add dark underside insulation to Part_Hood so it is not transparent/flat when open
bm_h = bmesh.new()
bm_h.from_mesh(hood_obj.data)
uv_h = bm_h.loops.layers.uv.verify()
orig_hood_faces = list(bm_h.faces)
for f in orig_hood_faces:
    v_rev = [bm_h.verts.new(v.co - Vector((0.0, 0.0, 0.005))) for v in reversed(f.verts)]
    f_rev = bm_h.faces.new(v_rev)
    for l in f_rev.loops:
        l[uv_h].uv = Vector((85.0 / 256.0, 250.0 / 256.0))
bm_h.to_mesh(hood_obj.data)
bm_h.free()

# Remove all other objects from scene
keep_names = {
    "Chassis", "Part_Hood",
    "Part_Wheel_FL", "Part_Wheel_FR", "Part_Wheel_RL", "Part_Wheel_RR"
}
for o in list(bpy.data.objects):
    if o.name not in keep_names:
        bpy.data.objects.remove(o, do_unlink=True)

# Set pivots before rotation and scaling
# Hood pivot at the cowl line:
pivot_hood = Vector((0.0, -0.741, 0.549))
cur_hood_loc = hood_obj.location.copy()
shift = pivot_hood - cur_hood_loc
for v in hood_obj.data.vertices:
    v.co -= shift
hood_obj.location = pivot_hood

# Wheels pivots at axle centers:
wheel_pivots = {
    "Part_Wheel_FL": Vector((0.416, -0.997, 0.1825)),
    "Part_Wheel_FR": Vector((-0.416, -0.997, 0.1825)),
    "Part_Wheel_RL": Vector((0.420, 0.6115, 0.1825)),
    "Part_Wheel_RR": Vector((-0.420, 0.6115, 0.1825)),
}
for name, pivot in wheel_pivots.items():
    obj = bpy.data.objects.get(name)
    if not obj:
        continue
    cur_loc = obj.location.copy()
    shift = pivot - cur_loc
    for v in obj.data.vertices:
        v.co -= shift
    obj.location = pivot

# Rotate 180 degrees around Z so car faces Godot forward (-Z)
rot_z = Matrix.Rotation(math.pi, 4, 'Z')
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.data.transform(rot_z)
        o.location = rot_z @ o.location
        o.data.update()

# Apply metric scale 1.62
for o in bpy.data.objects:
    if o.type == 'MESH':
        for v in o.data.vertices:
            v.co *= SCALE
        o.location *= SCALE
        o.data.update()

print("Applied 180 deg rotation and 1.62 scale.")
for o in bpy.data.objects:
    print(f"{o.name:15s}: Loc={[round(x,4) for x in o.location]}, Verts={len(o.data.vertices)}, Faces={len(o.data.polygons)}")

# Save blend
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

# Export GLB
bpy.ops.export_scene.gltf(
    filepath=GLB_OUT,
    export_format='GLB',
    use_selection=False,
    export_apply=False,
    export_yup=True
)
print("Exported GLB successfully:", GLB_OUT)
