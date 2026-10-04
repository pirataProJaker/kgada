import bpy
import os

HUMANOID_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Humanoid_Rigged.blend"
ZOMBIE_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Zombie_Rigged.blend"
OUT_GLB = r"C:\Users\Eduardo Contreras\Documents\play-sector-x\assets\characters\psx_humanoid.glb"

print("=== 1. ABRIENDO HUMANOID_RIGGED.BLEND ===")
bpy.ops.wm.open_mainfile(filepath=HUMANOID_BLEND)

armature_obj = bpy.data.objects.get("HumanoidArmature")
if not armature_obj:
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            armature_obj = obj
            break

print("Armature:", armature_obj.name)

# 2. Importar acciones de Zombie_Rigged.blend
print("=== 2. IMPORTANDO ACCIONES DE ZOMBIE ===")
actions_to_import = [
    ("walk", "zombie_walk"),
    ("attack", "zombie_attack"),
    ("die", "die")
]

with bpy.data.libraries.load(ZOMBIE_BLEND, link=False) as (data_from, data_to):
    data_to.actions = [src for src, _ in actions_to_import if src in data_from.actions]

# Renombrar y vincular NLA tracks
if not armature_obj.animation_data:
    armature_obj.animation_data_create()

existing_track_names = [t.name for t in armature_obj.animation_data.nla_tracks]

for src_name, new_name in actions_to_import:
    act = bpy.data.actions.get(src_name)
    if act:
        act.name = new_name
        print(f"Agregando acción {new_name} ({act.frame_range})")
        if new_name in existing_track_names:
            # Reemplazar strip
            t = armature_obj.animation_data.nla_tracks[new_name]
            for s in list(t.strips):
                t.strips.remove(s)
            t.strips.new(new_name, int(act.frame_range[0]), act)
        else:
            t = armature_obj.animation_data.nla_tracks.new()
            t.name = new_name
            t.strips.new(new_name, int(act.frame_range[0]), act)

# Guardar blend
bpy.ops.wm.save_as_mainfile(filepath=HUMANOID_BLEND)
print("Blend guardado con éxito.")

# 3. Exportar GLB
print(f"=== 3. EXPORTANDO GLB A {OUT_GLB} ===")
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects:
    if obj.type in {'MESH', 'ARMATURE'}:
        obj.select_set(True)

bpy.context.view_layer.objects.active = armature_obj

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_nla_strips=True,
    export_def_bones=False,
    export_current_frame=False
)
print(">>> EXPORTACIÓN GLB COMPLETADA CON ÉXITO <<<")
