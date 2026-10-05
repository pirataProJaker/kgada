import bpy

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\Suspicious Car.blend"
with bpy.data.libraries.load(blend_path) as (data_from, data_to):
    data_to.objects = ['Body']
body = data_to.objects[0]
mesh = body.data

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

print(f"sym_map[54] = {sym_map.get(54)}")
print(f"sym_map[72] = {sym_map.get(72)}")
