import bpy

obj = bpy.data.objects['Body']
mesh = obj.data

# Find symmetric face map: for each face with Center.x > 0, find the face with Center.x < 0 with same Y and Z and -X
sym_map = {}
for i, p1 in enumerate(mesh.polygons):
    if p1.center.x > 0.05:
        # Find matching face on negative X
        best_j = -1
        best_dist = 999.0
        target = (-p1.center.x, p1.center.y, p1.center.z)
        for j, p2 in enumerate(mesh.polygons):
            if p2.center.x < -0.05:
                d = (p2.center.x - target[0])**2 + (p2.center.y - target[1])**2 + (p2.center.z - target[2])**2
                if d < best_dist:
                    best_dist = d
                    best_j = j
        if best_dist < 0.001:
            sym_map[i] = best_j

print("Symmetric pairs found:", len(sym_map))

fl_faces = [17, 19, 70, 55, 8, 9, 67, 56]
fr_faces = [sym_map[i] for i in fl_faces]
print("FL faces:", fl_faces)
print("FR faces:", fr_faces)

hood_left = [20, 39]
hood_right = [sym_map[i] for i in hood_left]
print("Hood Left:", hood_left, "Hood Right:", hood_right)

trunk_left = [12, 44]
trunk_right = [sym_map[i] for i in trunk_left]
print("Trunk Left:", trunk_left, "Trunk Right:", trunk_right)

rl_cand1 = [25, 24, 69, 57]
rr_cand1 = [sym_map[i] for i in rl_cand1]
print("RL 4-face:", rl_cand1, "RR 4-face:", rr_cand1)

rl_cand2 = [25, 24, 69, 57, 27, 64]
rr_cand2 = [sym_map[i] for i in rl_cand2]
print("RL 6-face:", rl_cand2, "RR 6-face:", rr_cand2)

