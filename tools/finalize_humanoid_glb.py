import bpy

HUMANOID_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Humanoid_Rigged.blend"
OUT_GLB = r"C:\Users\Eduardo Contreras\Documents\play-sector-x\assets\characters\psx_humanoid.glb"

bpy.ops.wm.open_mainfile(filepath=HUMANOID_BLEND)
arm = bpy.data.objects['HumanoidArmature']

# 1. Eliminar acciones viejas corruptas
old_corrupted = ['die', 'attack', 'death', 'zombie_attack', 'zombie_walk']
for name in old_corrupted:
    a = bpy.data.actions.get(name)
    if a:
        bpy.data.actions.remove(a)

# 2. Renombrar las nuevas acciones horneadas
name_map = {
    'zombie_walk.001': 'zombie_walk',
    'zombie_attack.001': 'zombie_attack',
    'die.001': 'die'
}

for old_n, new_n in name_map.items():
    a = bpy.data.actions.get(old_n)
    if a:
        a.name = new_n
        print(f"Renombrado {old_n} -> {new_n}")

# 3. Crear copias para alias 'attack' y 'death'
z_att = bpy.data.actions.get('zombie_attack')
if z_att:
    att = z_att.copy()
    att.name = 'attack'

z_die = bpy.data.actions.get('die')
if z_die:
    d = z_die.copy()
    d.name = 'death'

# 4. Reconstruir NLA tracks en arm
all_action_names = [
    'idle', 'walk', 'run', 'jump', 'fall', 'land', 'roll', 'idle_sit',
    'zombie_walk', 'zombie_attack', 'die', 'attack', 'death'
]

print("=== RECONSTRUYENDO NLA TRACKS ===")
for t in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(t)

for act_name in all_action_names:
    act = bpy.data.actions.get(act_name)
    if act:
        track = arm.animation_data.nla_tracks.new()
        track.name = act.name
        track.strips.new(act.name, int(act.frame_range[0]), act)
        print(f" - Pista NLA: {act.name} ({act.frame_range})")

arm.animation_data.action = None

bpy.ops.wm.save_as_mainfile(filepath=HUMANOID_BLEND)
print("Blend guardado con éxito.")

# 5. Exportar GLB
print(f"=== EXPORTANDO GLB A {OUT_GLB} ===")
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects:
    if obj.type in {'MESH', 'ARMATURE'}:
        obj.select_set(True)
bpy.context.view_layer.objects.active = arm

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_nla_strips=True,
    export_def_bones=False,
    export_current_frame=False
)
print(">>> EXPORTACIÓN GLB FINALIZADA CON ÉXITO <<<")
