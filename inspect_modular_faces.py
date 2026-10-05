import bpy

# Load the saved sedan_modular.blend and inspect Part_Door_RL
blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=blend_path)

rl = bpy.data.objects['Part_Door_RL']
print("Part_Door_RL faces:")
for f in rl.data.polygons:
    vcos = [rl.data.vertices[vi].co for vi in f.vertices]
    # Remember pivot was at (0.490, 0.011, 0.340), so add pivot to get world coords:
    world_cos = [v + rl.location for v in vcos]
    ys = [v.y for v in world_cos]
    zs = [v.z for v in world_cos]
    print(f"Face {f.index}: Y=[{min(ys):.3f}..{max(ys):.3f}], Z=[{min(zs):.3f}..{max(zs):.3f}], Center=({sum(ys)/len(ys):.3f}, {sum(zs)/len(zs):.3f})")

# Also check Hood:
hood = bpy.data.objects['Part_Hood']
print("\nPart_Hood faces:")
for f in hood.data.polygons:
    vcos = [v + hood.location for v in [hood.data.vertices[vi].co for vi in f.vertices]]
    zs = [v.z for v in vcos]
    ys = [v.y for v in vcos]
    print(f"Hood face {f.index}: Z=[{min(zs):.3f}..{max(zs):.3f}], Y=[{min(ys):.3f}..{max(ys):.3f}], Norm={f.normal}")
