import bpy
import math
import os
from mathutils import Vector

HUMANOID_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Humanoid_Rigged.blend"
Z_BLEND = r"C:\Users\Eduardo Contreras\Desktop\psx-creatures-free\blender\psx-creatures-free.blend"
OUT_GLB = r"C:\Users\Eduardo Contreras\Documents\play-sector-x\assets\characters\psx_humanoid.glb"

print("=== 1. ABRIENDO HUMANOID_RIGGED.BLEND ===")
bpy.ops.wm.open_mainfile(filepath=HUMANOID_BLEND)
arm = bpy.data.objects['HumanoidArmature']
mesh_obj = bpy.data.objects.get("HumanoidBase_NotOverlapping")

# 2. Cargar objetos de zombie
print("=== 2. CARGANDO PARTES DE ZOMBIE PARA RETARGETING VISUAL ===")
z_parts = [
    'zombie_woman', 'zombie_woman_torso', 'zombie_woman_head',
    'zombie_woman_arm_l', 'zombie_woman_forearm_l', 'zombie_woman_hand_l',
    'zombie_woman_arm_r', 'zombie_woman_forearm_r', 'zombie_woman_hand_r',
    'zombie_woman_thigh_l', 'zombie_woman_shin_l', 'zombie_woman_foot_l',
    'zombie_woman_thigh_r', 'zombie_woman_shin_r', 'zombie_woman_foot_r'
]

with bpy.data.libraries.load(Z_BLEND, link=False) as (data_from, data_to):
    data_to.objects = z_parts

for o in data_to.objects:
    bpy.context.collection.objects.link(o)

# 3. Empties para Head y Feet
head_target = bpy.data.objects.new('RetargetHeadTarget', None)
bpy.context.collection.objects.link(head_target)
head_target.parent = bpy.data.objects['zombie_woman_head']
head_target.location = (0.0, 0.0, 0.30)

foot_l_target = bpy.data.objects.new('RetargetFootLTarget', None)
bpy.context.collection.objects.link(foot_l_target)
foot_l_target.parent = bpy.data.objects['zombie_woman_foot_l']
foot_l_target.location = (0.0, -0.15, -0.04)

foot_r_target = bpy.data.objects.new('RetargetFootRTarget', None)
bpy.context.collection.objects.link(foot_r_target)
foot_r_target.parent = bpy.data.objects['zombie_woman_foot_r']
foot_r_target.location = (0.0, -0.15, -0.04)

zombie_anims_to_bake = [
    ("walk", "zombie_walk", 0, 45),
    ("attack", "zombie_attack", 0, 42),
    ("death", "die", 0, 66)
]

baked_zombie_actions = []

print("=== 3. RETARGETING VISUAL Y HORNEADO DIRECTO EN HUMANOID ARMATURE ===")
for track_name, clean_name, f_start, f_end in zombie_anims_to_bake:
    print(f"-> Horneando {clean_name} ({f_start}..{f_end}) desde track '{track_name}'...")
    
    # Activar el track correspondiente en las partes zombie
    for o in data_to.objects:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != track_name)

    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')

    # Limpiar constraints viejos
    for pb in arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)

    # 1. Hips (posición + alineación con torso)
    c_loc = arm.pose.bones['Hips'].constraints.new('COPY_LOCATION')
    c_loc.target = bpy.data.objects['zombie_woman']

    c_track_hips = arm.pose.bones['Hips'].constraints.new('DAMPED_TRACK')
    c_track_hips.target = bpy.data.objects['zombie_woman_torso']
    c_track_hips.track_axis = 'TRACK_Y'

    # 2. Chest & Head
    c_track_chest = arm.pose.bones['Chest'].constraints.new('DAMPED_TRACK')
    c_track_chest.target = bpy.data.objects['zombie_woman_head']
    c_track_chest.track_axis = 'TRACK_Y'

    c_track_head = arm.pose.bones['Head'].constraints.new('DAMPED_TRACK')
    c_track_head.target = head_target
    c_track_head.track_axis = 'TRACK_Y'

    # 3. Extremidades
    limb_damped = [
        ('Clavicle.L', 'zombie_woman_arm_l'),
        ('UpperArm.L', 'zombie_woman_forearm_l'),
        ('Forearm.L', 'zombie_woman_hand_l'),
        ('Clavicle.R', 'zombie_woman_arm_r'),
        ('UpperArm.R', 'zombie_woman_forearm_r'),
        ('Forearm.R', 'zombie_woman_hand_r'),
        ('Thigh.L', 'zombie_woman_shin_l'),
        ('Shin.L', 'zombie_woman_foot_l'),
        ('Foot.L', 'RetargetFootLTarget'),
        ('Thigh.R', 'zombie_woman_shin_r'),
        ('Shin.R', 'zombie_woman_foot_r'),
        ('Foot.R', 'RetargetFootRTarget'),
    ]

    for bname, target_name in limb_damped:
        c = arm.pose.bones[bname].constraints.new('DAMPED_TRACK')
        c.target = bpy.data.objects[target_name]
        c.track_axis = 'TRACK_Y'

    bpy.ops.nla.bake(
        frame_start=f_start,
        frame_end=f_end,
        only_selected=False,
        visual_keying=True,
        clear_constraints=True,
        bake_types={'POSE'}
    )

    baked = arm.animation_data.action
    baked.name = clean_name
    baked_zombie_actions.append(baked)

# Limpiar objetos temporales de zombie
print("=== 4. LIMPIANDO OBJETOS TEMPORALES ===")
for o in data_to.objects:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.data.objects.remove(head_target, do_unlink=True)
bpy.data.objects.remove(foot_l_target, do_unlink=True)
bpy.data.objects.remove(foot_r_target, do_unlink=True)

# Limpiar acciones de zombie temporales
for act in list(bpy.data.actions):
    if act.name.startswith("zombie_woman"):
        bpy.data.actions.remove(act)

# Añadir alias 'attack' y 'death'
for act in baked_zombie_actions:
    if act.name == "zombie_attack":
        att = act.copy()
        att.name = "attack"
        baked_zombie_actions.append(att)
    elif act.name == "die":
        d = act.copy()
        d.name = "death"
        baked_zombie_actions.append(d)

# Actualizar NLA tracks en arm
print("=== 5. ACTUALIZANDO NLA TRACKS EN HUMANOID ===")
for act in baked_zombie_actions:
    if act.name in arm.animation_data.nla_tracks:
        t = arm.animation_data.nla_tracks[act.name]
        for s in list(t.strips):
            t.strips.remove(s)
        t.strips.new(act.name, int(act.frame_range[0]), act)
    else:
        t = arm.animation_data.nla_tracks.new()
        t.name = act.name
        t.strips.new(act.name, int(act.frame_range[0]), act)

arm.animation_data.action = None

bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=HUMANOID_BLEND)
print("Blend guardado con éxito.")

# Exportar GLB limpio
print(f"=== 6. EXPORTANDO GLB A {OUT_GLB} ===")
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
print(">>> RETARGETING VISUAL DE ZOMBIE A HUMANOIDE COMPLETADO CON ÉXITO <<<")
