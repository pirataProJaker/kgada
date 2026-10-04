import bpy
import math
import os
from mathutils import Vector

# Rutas del proyecto
SRC_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Humanoid.blend"
FBX_SOURCE = r"C:\Users\Eduardo Contreras\Desktop\RiggedAnimsGuy\PSXHumanRigged+Animations.fbx"
OUT_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Humanoid_Rigged.blend"
OUT_GLB_PROJECT = r"C:\Users\Eduardo Contreras\Documents\play-sector-x\assets\characters\psx_humanoid.glb"

os.makedirs(os.path.dirname(OUT_GLB_PROJECT), exist_ok=True)

print("=== 1. CARGANDO BASE HUMANOID MESH ===")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)

# Limpiar objetos que no sean la malla del humanoide (por ejemplo Icosphere)
for obj in list(bpy.data.objects):
    if obj.type == 'MESH' and not obj.name.startswith("HumanoidBase"):
        bpy.data.objects.remove(obj, do_unlink=True)

# Limpiar acciones previas
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

mesh_obj = bpy.data.objects.get("HumanoidBase_NotOverlapping")
if not mesh_obj:
    mesh_obj = [o for o in bpy.data.objects if o.type == 'MESH'][0]

bpy.context.view_layer.objects.active = mesh_obj
mesh_obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# === 2. ESQUELETO OPTIMIZADO DE 15 HUESOS (CON PIES Y COLUMNA RECTIFICADA) ===
print("=== 2. CONSTRUYENDO ESQUELETO HUMANOIDE (15 HUESOS) ===")
armature_data = bpy.data.armatures.new("HumanoidArmature")
armature_obj = bpy.data.objects.new("HumanoidArmature", armature_data)
bpy.context.collection.objects.link(armature_obj)

bpy.context.view_layer.objects.active = armature_obj
armature_obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')

eb = armature_data.edit_bones

bones_def = {
    # Columna alineada verticalmente para evitar arqueo hacia atrás
    "Hips": (Vector((0.0, 0.0, 0.95)), Vector((0.0, 0.0, 1.16)), None),
    "Chest": (Vector((0.0, 0.0, 1.16)), Vector((0.0, -0.01, 1.48)), "Hips"),
    "Head": (Vector((0.0, -0.01, 1.48)), Vector((0.0, -0.02, 1.78)), "Chest"),

    "Clavicle.L": (Vector((0.03, -0.02, 1.48)), Vector((0.19, 0.02, 1.46)), "Chest"),
    "UpperArm.L": (Vector((0.19, 0.02, 1.46)), Vector((0.50, 0.02, 1.28)), "Clavicle.L"),
    "Forearm.L": (Vector((0.50, 0.02, 1.28)), Vector((0.74, 0.02, 1.10)), "UpperArm.L"),

    "Clavicle.R": (Vector((-0.03, -0.02, 1.48)), Vector((-0.19, 0.02, 1.46)), "Chest"),
    "UpperArm.R": (Vector((-0.19, 0.02, 1.46)), Vector((-0.50, 0.02, 1.28)), "Clavicle.R"),
    "Forearm.R": (Vector((-0.50, 0.02, 1.28)), Vector((-0.74, 0.02, 1.10)), "UpperArm.R"),

    # Piernas con articulación de tobillo y pie para apoyo total en el suelo
    "Thigh.L": (Vector((0.10, 0.01, 0.95)), Vector((0.15, -0.03, 0.54)), "Hips"),
    "Shin.L": (Vector((0.15, -0.03, 0.54)), Vector((0.19, 0.016, 0.09)), "Thigh.L"),
    "Foot.L": (Vector((0.19, 0.016, 0.09)), Vector((0.19, -0.16, 0.02)), "Shin.L"),

    "Thigh.R": (Vector((-0.10, 0.01, 0.95)), Vector((-0.15, -0.03, 0.54)), "Hips"),
    "Shin.R": (Vector((-0.15, -0.03, 0.54)), Vector((-0.19, 0.016, 0.09)), "Thigh.R"),
    "Foot.R": (Vector((-0.19, 0.016, 0.09)), Vector((-0.19, -0.16, 0.02)), "Shin.R"),
}

for bname, (head, tail, _) in bones_def.items():
    b = eb.new(bname)
    b.head = head
    b.tail = tail

for bname, (_, _, parent) in bones_def.items():
    if parent:
        eb[bname].parent = eb[parent]

bpy.ops.object.mode_set(mode='OBJECT')

# Skinning de alta precisión
print("=== 3. ASIGNANDO PESOS DE PIEL ===")
bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
armature_obj.select_set(True)
bpy.context.view_layer.objects.active = armature_obj
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

# Malla Overlapping
mesh_over = bpy.data.objects.get("HumanoidBase_Overlapping")
if mesh_over:
    bpy.ops.object.select_all(action='DESELECT')
    mesh_over.select_set(True)
    armature_obj.select_set(True)
    bpy.context.view_layer.objects.active = armature_obj
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    mesh_over.hide_render = True
    mesh_over.hide_viewport = True

# === 4. IMPORTAR FBX CON ANIMACIONES MOCAP Y RETARGETING ===
print("=== 4. IMPORTANDO FBX MOCAP PARA RETARGETING ===")
bpy.ops.import_scene.fbx(filepath=FBX_SOURCE)
fbx_arm = bpy.data.objects.get("Rig")
fbx_mesh = bpy.data.objects.get("Mesh")
if fbx_mesh:
    bpy.data.objects.remove(fbx_mesh, do_unlink=True)

# Añadir hueso auxiliar HeadTarget en FBX para enderezar la mirada al frente (evitar que mire al suelo)
bpy.context.view_layer.objects.active = fbx_arm
bpy.ops.object.mode_set(mode='EDIT')
eb_fbx = fbx_arm.data.edit_bones
head_target = eb_fbx.new("HeadTarget")
head_target.head = eb_fbx["spine.005"].head
head_target.tail = eb_fbx["spine.005"].head + Vector((0.0, 0.0, 0.28))
head_target.parent = eb_fbx["spine.005"]
bpy.ops.object.mode_set(mode='OBJECT')

# Animaciones a transferir (Nombre en FBX -> Nombre limpio, inicio, fin, desfase hacia atrás de cabeza en grados)
# En walk/run el torso se inclina hacia adelante, por lo que inclinamos la cabeza hacia atrás (23° en walk, 26° en run)
# para que la mirada quede nivelada al frente hacia el horizonte en vez de clavar los ojos en el piso.
anims_to_bake = [
    ("Rig|Rig|Idle", "idle", 1, 60, 4.0),
    ("Rig|Rig|Walk", "walk", 1, 30, 19.0),
    ("Rig|Rig|Run", "run", 1, 30, 24.0),
    ("Rig|Rig|Jump_Up", "jump", 1, 30, 10.0),
    ("Rig|Rig|Fall", "fall", 1, 30, 15.0),
    ("Rig|Rig|Land", "land", 1, 30, 15.0),
    ("Rig|Rig|Roll", "roll", 1, 38, 5.0),
    ("Rig|Rig|Idle_Sit", "idle_sit", 1, 60, 15.0),
]

limb_mapping = [
    ("Clavicle.L", "shoulder.L"),
    ("UpperArm.L", "upper_arm.L"),
    ("Forearm.L", "forearm.L"),
    ("Clavicle.R", "shoulder.R"),
    ("UpperArm.R", "upper_arm.R"),
    ("Forearm.R", "forearm.R"),
    ("Thigh.L", "thigh.L"),
    ("Shin.L", "shin.L"),
    ("Foot.L", "foot.L"),
    ("Thigh.R", "thigh.R"),
    ("Shin.R", "shin.R"),
    ("Foot.R", "foot.R"),
]

baked_actions = []

print("=== 5. RETARGETING Y HORNEADO DE ANIMACIONES CON POSTURA NATURAL ===")
for fbx_name, clean_name, f_start, f_end, head_deg in anims_to_bake:
    fbx_act = bpy.data.actions.get(fbx_name)
    if not fbx_act:
        print(f"Warning: Acción {fbx_name} no encontrada")
        continue

    print(f"-> Retargeting: {clean_name} ({f_start}..{f_end}) [Head offset: +{head_deg}°]")
    
    # Ajustar orientación de HeadTarget para esta animación
    bpy.context.view_layer.objects.active = fbx_arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb_fbx = fbx_arm.data.edit_bones
    rad = math.radians(head_deg)
    y_off = 0.28 * math.sin(rad)
    z_off = 0.28 * math.cos(rad)
    eb_fbx["HeadTarget"].tail = eb_fbx["spine.005"].head + Vector((0.0, y_off, z_off))
    bpy.ops.object.mode_set(mode='OBJECT')

    fbx_arm.animation_data.action = fbx_act

    # Limpiar constraints previos
    for pb in armature_obj.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)

    # 1. Hips Location (pelvis en altura correcta)
    pb_hips = armature_obj.pose.bones["Hips"]
    c_loc = pb_hips.constraints.new('COPY_LOCATION')
    c_loc.target = fbx_arm
    c_loc.subtarget = "spine"

    # 2. Hips Rotation (usar spine.001 en lugar de spine para evitar pelvis hiper-inclinada hacia adelante)
    c_rot = pb_hips.constraints.new('COPY_ROTATION')
    c_rot.target = fbx_arm
    c_rot.subtarget = "spine.001"

    # 3. Chest Rotation (alineado naturalmente al tórax)
    c_chest = armature_obj.pose.bones["Chest"].constraints.new('COPY_ROTATION')
    c_chest.target = fbx_arm
    c_chest.subtarget = "spine.003"

    # 4. Head Rotation (usando HeadTarget para mirar al frente y no al suelo)
    c_head = armature_obj.pose.bones["Head"].constraints.new('COPY_ROTATION')
    c_head.target = fbx_arm
    c_head.subtarget = "HeadTarget"

    # 5. Extremidades y pies
    for target_b, source_b in limb_mapping:
        pb = armature_obj.pose.bones[target_b]
        c = pb.constraints.new('DAMPED_TRACK')
        c.target = fbx_arm
        c.subtarget = source_b
        c.head_tail = 1.0
        c.track_axis = 'TRACK_Y'

    # Hornear animación visual
    bpy.context.view_layer.objects.active = armature_obj
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.nla.bake(
        frame_start=f_start,
        frame_end=f_end,
        only_selected=False,
        visual_keying=True,
        clear_constraints=True,
        bake_types={'POSE'}
    )

    baked = armature_obj.animation_data.action
    baked.name = clean_name
    baked_actions.append(baked)

# Eliminar el rig del FBX para no exportar nada innecesario
bpy.data.objects.remove(fbx_arm, do_unlink=True)

# Limpiar todas las acciones del FBX de bpy.data.actions, dejando SOLO las horneadas
for act in list(bpy.data.actions):
    if act not in baked_actions:
        bpy.data.actions.remove(act)

# === 5b. IMPORTAR ACCIONES DEL ZOMBIE PARA BASE HUMANOIDE ===
ZOMBIE_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Zombie_Rigged.blend"
if os.path.exists(ZOMBIE_BLEND):
    print("=== 5b. IMPORTANDO ACCIONES DEL ZOMBIE ===")
    prev_actions = set(bpy.data.actions.keys())
    with bpy.data.libraries.load(ZOMBIE_BLEND, link=False) as (data_from, data_to):
        data_to.actions = ["walk", "attack", "die"]

    new_actions = [bpy.data.actions[k] for k in bpy.data.actions.keys() if k not in prev_actions]
    for act in new_actions:
        if "walk" in act.name.lower():
            act.name = "zombie_walk"
            baked_actions.append(act)
            print(f"-> Acción zombie añadida al humanoide: {act.name} ({act.frame_range})")
        elif "attack" in act.name.lower():
            act.name = "zombie_attack"
            baked_actions.append(act)
            print(f"-> Acción zombie añadida al humanoide: {act.name} ({act.frame_range})")
            attack_copy = act.copy()
            attack_copy.name = "attack"
            baked_actions.append(attack_copy)
            print(f"-> Alias añadido al humanoide: {attack_copy.name}")
        elif "die" in act.name.lower():
            act.name = "die"
            baked_actions.append(act)
            print(f"-> Acción zombie añadida al humanoide: {act.name} ({act.frame_range})")
            death_copy = act.copy()
            death_copy.name = "death"
            baked_actions.append(death_copy)
            print(f"-> Alias añadido al humanoide: {death_copy.name}")

# === 6. CREAR PISTAS NLA LIMPIAS ===
print("=== 6. CONFIGURANDO NLA TRACKS PARA EXPORTACIÓN ===")
if not armature_obj.animation_data:
    armature_obj.animation_data_create()

for t in list(armature_obj.animation_data.nla_tracks):
    armature_obj.animation_data.nla_tracks.remove(t)

for act in baked_actions:
    track = armature_obj.animation_data.nla_tracks.new()
    track.name = act.name
    strip = track.strips.new(act.name, int(act.frame_range[0]), act)
    strip.name = act.name

# Desactivar acción activa para que glTF exporte exclusivamente las pistas NLA sin duplicar 'walk_001'
armature_obj.animation_data.action = None

# === 7. GUARDAR .BLEND Y EXPORTAR GLB ===
print(f"=== 7. GUARDANDO BLEND: {OUT_BLEND} ===")
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

print(f"=== 8. EXPORTANDO GLB LIMPIO AL PROYECTO: {OUT_GLB_PROJECT} ===")
bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
armature_obj.select_set(True)
if mesh_over:
    mesh_over.select_set(True)
bpy.context.view_layer.objects.active = armature_obj

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB_PROJECT,
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_nla_strips=True,
    export_def_bones=False,
    export_current_frame=False
)

print(">>> ¡RETARGETING A 15 HUESOS (CON PIES Y CABEZA MIRANDO AL FRENTE) COMPLETADO! <<<")
