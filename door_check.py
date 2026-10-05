import bpy

with open(r"c:\Users\PC 1\PSX\door_check.txt", "w") as f:
    for name in ["Part_Door_FL", "Part_Door_RL", "Part_Hood", "Part_Trunk", "Chassis"]:
        obj = bpy.data.objects.get(name)
        if not obj:
            continue
        mesh = obj.data
        f.write(f"\n=== {name} (polys: {len(mesh.polygons)}, verts: {len(mesh.vertices)}) ===\n")
        f.write(f"Location: {obj.location}\n")
        for i, poly in enumerate(mesh.polygons):
            center_world = obj.matrix_world @ poly.center
            f.write(f"  Face {i}: center_local={poly.center}, center_world={center_world}, normal={poly.normal}\n")
            for vi in poly.vertices:
                v = mesh.vertices[vi]
                vw = obj.matrix_world @ v.co
                f.write(f"    v{vi}: local=({v.co.x:.3f}, {v.co.y:.3f}, {v.co.z:.3f}) world=({vw.x:.3f}, {vw.y:.3f}, {vw.z:.3f})\n")

print("Door check written!")
