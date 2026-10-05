import bpy
from mathutils import Vector

# Inspect all faces on the side profile
# In uv_texture_overlay:
# The side profile is in V in [0.60 .. 0.86], U in [0.0 .. 1.0]

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']

for obj in data_to.objects:
    bpy.context.scene.collection.objects.link(obj)

body = bpy.data.objects['Body']
mesh = body.data
uv_layer = mesh.uv_layers.active.data

print("\n=== SIDE FACES IN UV ORDER (U increasing from Front to Back) ===")
# Left side faces (X > 0.1)
left_side = []
for p in mesh.polygons:
    if p.center.x > 0.1 and p.normal.x > 0.3:
        uvs = [uv_layer[li].uv for li in p.loop_indices]
        u_avg = sum(u.x for u in uvs) / len(uvs)
        v_avg = sum(u.y for u in uvs) / len(uvs)
        if 0.60 <= v_avg <= 0.86:
            left_side.append((u_avg, v_avg, p.index, p))

left_side.sort(key=lambda item: (round(item[0], 2), item[1]))

for u, v, idx, p in left_side:
    verts = [mesh.vertices[vi].co for vi in p.vertices]
    y_min = min(co.y for co in verts)
    y_max = max(co.y for co in verts)
    z_min = min(co.z for co in verts)
    z_max = max(co.z for co in verts)
    print(f"Face {idx:3d}: U_avg={u:.3f}, V_avg={v:.3f} | Y=[{y_min:6.3f}..{y_max:6.3f}] Z=[{z_min:6.3f}..{z_max:6.3f}] VertCount={len(p.vertices)}")
