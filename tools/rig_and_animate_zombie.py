import bpy
import math
import os
from mathutils import Vector

# Rutas del proyecto
SRC_ZOMBIE_BLEND = r"C:\Users\Eduardo Contreras\Desktop\psx-creatures-free\blender\psx-creatures-free.blend"
OUT_BLEND = r"C:\Users\Eduardo Contreras\Desktop\Base Humanoid Mesh\Zombie_Rigged.blend"
OUT_GLB_PROJECT = r"C:\Users\Eduardo Contreras\Documents\play-sector-x\assets\characters\psx_zombie.glb"

os.makedirs(os.path.dirname(OUT_GLB_PROJECT), exist_ok=True)
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)

print("=== 1. CARGANDO MODELO ZOMBIE PSX ===")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=SRC_ZOMBIE_BLEND)

# Mapeo de objetos del zombie a los 15 huesos estándar
vg_map = {
    "zombie_woman": "Hips",
    "zombie_woman_torso": "Chest",
    "zombie_woman_head": "Head",
    "zombie_woman_arm_l": "UpperArm.L",
    "zombie_woman_forearm_l": "Forearm.L",
    "zombie_woman_hand_l": "Forearm.L",
    "zombie_woman_arm_r": "UpperArm.R",
    "zombie_woman_forearm_r": "Forearm.R",
    "zombie_woman_hand_r": "Forearm.R",
    "zombie_woman_thigh_l": "Thigh.L",
    "zombie_woman_shin_l": "Shin.L",
    "zombie_woman_foot_l": "Foot.L",
    "zombie_woman_thigh_r": "Thigh.R",
    "zombie_woman_shin_r": "Shin.R",
    "zombie_woman_foot_r": "Foot.R",
}

# Desactivar NLA para evaluar en pose de descanso (rest pose)
for obj in bpy.data.objects:
    if obj.animation_data:
        for t in obj.animation_data.nla_tracks:
            t.mute = True

bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()

# 2. Clonar partes para unirlas en una única malla con vertex groups asignados
print("=== 2. CREANDO MALLA UNIFICADA Y ASIGNANDO VERTEX GROUPS ===")
zombie_parts = list(vg_map.keys())
cloned_parts = []

for pname in zombie_parts:
    src_obj = bpy.data.objects[pname]
    clone = src_obj.copy()
    clone.data = src_obj.data.copy()
    clone.animation_data_clear()
    clone.parent = None
    clone.matrix_world = src_obj.matrix_world.copy()
    bpy.context.collection.objects.link(clone)
    
    vg_name = vg_map[pname]
    vg = clone.vertex_groups.new(name=vg_name)
    vg.add(list(range(len(clone.data.vertices))), 1.0, 'REPLACE')
    
    cloned_parts.append(clone)

bpy.ops.object.select_all(action='DESELECT')
for cp in cloned_parts:
    cp.select_set(True)
bpy.context.view_layer.objects.active = cloned_parts[0]
bpy.ops.object.join()

zombie_mesh = bpy.context.view_layer.objects.active
zombie_mesh.name = "Zombie_Mesh"
print(f"Malla Zombie_Mesh creada con éxito ({len(zombie_mesh.data.vertices)} vértices).")

# 3. Construir esqueleto HumanoidArmature de 15 huesos alineado a los pivotes del zombie
print("=== 3. CONSTRUYENDO ESQUELETO HUMANOIDE (15 HUESOS) ===")
armature_data = bpy.data.armatures.new("HumanoidArmature")
armature_obj = bpy.data.objects.new("HumanoidArmature", armature_data)
bpy.context.collection.objects.link(armature_obj)
bpy.context.view_layer.objects.active = armature_obj
bpy.ops.object.mode_set(mode='EDIT')
eb = armature_data.edit_bones

bones_def = {
    "Hips": (Vector((0.0, 0.0, 0.8846)), Vector((0.0, 0.0, 0.9606)), None),
    "Chest": (Vector((0.0, 0.0, 0.9606)), Vector((0.0, -0.0743, 1.4298)), "Hips"),
    "Head": (Vector((0.0, -0.0743, 1.4298)), Vector((0.0, -0.0743, 1.72)), "Chest"),
    
    "Clavicle.L": (Vector((0.03, -0.04, 1.35)), Vector((0.1661, -0.0624, 1.3547)), "Chest"),
    "UpperArm.L": (Vector((0.1661, -0.0624, 1.3547)), Vector((0.1996, -0.0039, 1.0876)), "Clavicle.L"),
    "Forearm.L": (Vector((0.1996, -0.0039, 1.0876)), Vector((0.2297, -0.0217, 0.8431)), "UpperArm.L"),
    
    "Clavicle.R": (Vector((-0.03, -0.04, 1.35)), Vector((-0.1661, -0.0624, 1.3547)), "Chest"),
    "UpperArm.R": (Vector((-0.1661, -0.0624, 1.3547)), Vector((-0.1996, -0.0356, 1.0826)), "Clavicle.R"),
    "Forearm.R": (Vector((-0.1996, -0.0356, 1.0826)), Vector((-0.2297, -0.0585, 0.8385)), "UpperArm.R"),
    
    "Thigh.L": (Vector((0.0926, 0.0, 0.8656)), Vector((0.0926, -0.0427, 0.4594)), "Hips"),
    "Shin.L": (Vector((0.0926, -0.0427, 0.4594)), Vector((0.0926, -0.0152, 0.0661)), "Thigh.L"),
    "Foot.L": (Vector((0.0926, -0.0152, 0.0661)), Vector((0.0926, -0.16, 0.02)), "Shin.L"),
    
    "Thigh.R": (Vector((-0.0926, 0.0, 0.8656)), Vector((-0.0926, -0.0214, 0.4577)), "Hips"),
    "Shin.R": (Vector((-0.0926, -0.0214, 0.4577)), Vector((-0.0926, -0.0007, 0.0640)), "Thigh.R"),
    "Foot.R": (Vector((-0.0926, -0.0007, 0.0640)), Vector((-0.0926, -0.16, 0.02)), "Shin.R"),
}

for bname, (head, tail, _) in bones_def.items():
    b = eb.new(bname)
    b.head = head
    b.tail = tail

for bname, (_, _, parent) in bones_def.items():
    if parent:
        eb[bname].parent = eb[parent]

bpy.ops.object.mode_set(mode='OBJECT')

# Vincular modificador Armature
mod = zombie_mesh.modifiers.new(name="Armature", type='ARMATURE')
mod.object = armature_obj
zombie_mesh.parent = armature_obj

# 4. Crear rig auxiliar ZombieSourceRig para capturar orientación de columna y cabeza
print("=== 4. CONFIGURANDO RIG GUÍA PARA RETARGETING ===")
src_arm_data = bpy.data.armatures.new("ZombieSourceRig")
src_arm_obj = bpy.data.objects.new("ZombieSourceRig", src_arm_data)
bpy.context.collection.objects.link(src_arm_obj)
bpy.context.view_layer.objects.active = src_arm_obj
bpy.ops.object.mode_set(mode='EDIT')
eb_src = src_arm_data.edit_bones

b_hips = eb_src.new("Hips")
b_hips.head = Vector((0.0, 0.0, 0.8846))
b_hips.tail = Vector((0.0, 0.0, 0.9606))

b_chest = eb_src.new("Chest")
b_chest.head = Vector((0.0, 0.0, 0.9606))
b_chest.tail = Vector((0.0, -0.0743, 1.4298))
b_chest.parent = b_hips

b_head = eb_src.new("Head")
b_head.head = Vector((0.0, -0.0743, 1.4298))
b_head.tail = Vector((0.0, -0.0743, 1.72))
b_head.parent = b_chest

b_foot_l = eb_src.new("Foot.L")
b_foot_l.head = Vector((0.0926, -0.0152, 0.0661))
b_foot_l.tail = Vector((0.0926, -0.16, 0.02))

b_foot_r = eb_src.new("Foot.R")
b_foot_r.head = Vector((-0.0926, -0.0007, 0.0640))
b_foot_r.tail = Vector((-0.0926, -0.16, 0.02))

bpy.ops.object.mode_set(mode='OBJECT')

bpy.context.view_layer.objects.active = src_arm_obj
bpy.ops.object.mode_set(mode='POSE')

c = src_arm_obj.pose.bones["Hips"].constraints.new('COPY_LOCATION')
c.target = bpy.data.objects["zombie_woman"]
c = src_arm_obj.pose.bones["Hips"].constraints.new('DAMPED_TRACK')
c.target = bpy.data.objects["zombie_woman_torso"]
c.track_axis = 'TRACK_Y'

c = src_arm_obj.pose.bones["Chest"].constraints.new('DAMPED_TRACK')
c.target = bpy.data.objects["zombie_woman_head"]
c.track_axis = 'TRACK_Y'

head_tip = bpy.data.objects.new("ZombieHeadTip", None)
bpy.context.collection.objects.link(head_tip)
head_tip.parent = bpy.data.objects["zombie_woman_head"]
head_tip.location = (0.0, 0.0, 0.30)

c = src_arm_obj.pose.bones["Head"].constraints.new('DAMPED_TRACK')
c.target = head_tip
c.track_axis = 'TRACK_Y'

foot_l_tip = bpy.data.objects.new("ZombieFootLTip", None)
bpy.context.collection.objects.link(foot_l_tip)
foot_l_tip.parent = bpy.data.objects["zombie_woman_foot_l"]
foot_l_tip.location = (0.0, -0.15, -0.04)

c = src_arm_obj.pose.bones["Foot.L"].constraints.new('COPY_LOCATION')
c.target = bpy.data.objects["zombie_woman_foot_l"]
c = src_arm_obj.pose.bones["Foot.L"].constraints.new('DAMPED_TRACK')
c.target = foot_l_tip
c.track_axis = 'TRACK_Y'

foot_r_tip = bpy.data.objects.new("ZombieFootRTip", None)
bpy.context.collection.objects.link(foot_r_tip)
foot_r_tip.parent = bpy.data.objects["zombie_woman_foot_r"]
foot_r_tip.location = (0.0, -0.15, -0.04)

c = src_arm_obj.pose.bones["Foot.R"].constraints.new('COPY_LOCATION')
c.target = bpy.data.objects["zombie_woman_foot_r"]
c = src_arm_obj.pose.bones["Foot.R"].constraints.new('DAMPED_TRACK')
c.target = foot_r_tip
c.track_axis = 'TRACK_Y'

bpy.ops.object.mode_set(mode='OBJECT')

# 5. Hornear animaciones
print("=== 5. RETARGETING Y HORNEADO DE TODAS LAS ANIMACIONES ===")
zombie_anims = [
    ("idle", "idle", 0, 90),
    ("walk", "walk", 0, 45),
    ("walk", "run", 0, 30), # 'run' para compatibilidad total con Zombie.gd (carrera rápida)
    ("attack", "attack", 0, 42),
    ("hit", "hit", 0, 18),
    ("death", "death", 0, 66),
    ("death", "die", 0, 66), # alias 'die' para compatibilidad con Zombie.gd
]

limb_targets = [
    ("Clavicle.L", bpy.data.objects["zombie_woman_arm_l"]),
    ("UpperArm.L", bpy.data.objects["zombie_woman_forearm_l"]),
    ("Forearm.L", bpy.data.objects["zombie_woman_hand_l"]),
    ("Clavicle.R", bpy.data.objects["zombie_woman_arm_r"]),
    ("UpperArm.R", bpy.data.objects["zombie_woman_forearm_r"]),
    ("Forearm.R", bpy.data.objects["zombie_woman_hand_r"]),
    ("Thigh.L", bpy.data.objects["zombie_woman_shin_l"]),
    ("Shin.L", bpy.data.objects["zombie_woman_foot_l"]),
    ("Thigh.R", bpy.data.objects["zombie_woman_shin_r"]),
    ("Shin.R", bpy.data.objects["zombie_woman_foot_r"]),
]

baked_actions = []

for track_name, clean_name, f_start, f_end in zombie_anims:
    print(f"-> Horneando: {clean_name} ({f_start}..{f_end}) desde track '{track_name}'...")
    
    for pname in zombie_parts:
        obj = bpy.data.objects[pname]
        if obj.animation_data:
            for t in obj.animation_data.nla_tracks:
                t.mute = (t.name != track_name)
                
    bpy.context.view_layer.objects.active = armature_obj
    bpy.ops.object.mode_set(mode='POSE')
    
    for pb in armature_obj.pose.bones:
        for c_item in list(pb.constraints):
            pb.constraints.remove(c_item)
            
    pb_hips = armature_obj.pose.bones["Hips"]
    c_loc = pb_hips.constraints.new('COPY_LOCATION')
    c_loc.target = src_arm_obj
    c_loc.subtarget = "Hips"
    
    c_rot = pb_hips.constraints.new('COPY_ROTATION')
    c_rot.target = src_arm_obj
    c_rot.subtarget = "Hips"
    
    c = armature_obj.pose.bones["Chest"].constraints.new('COPY_ROTATION')
    c.target = src_arm_obj
    c.subtarget = "Chest"
    
    c = armature_obj.pose.bones["Head"].constraints.new('COPY_ROTATION')
    c.target = src_arm_obj
    c.subtarget = "Head"
    
    c = armature_obj.pose.bones["Foot.L"].constraints.new('COPY_ROTATION')
    c.target = src_arm_obj
    c.subtarget = "Foot.L"
    
    c = armature_obj.pose.bones["Foot.R"].constraints.new('COPY_ROTATION')
    c.target = src_arm_obj
    c.subtarget = "Foot.R"
    
    for bname, tobj in limb_targets:
        pb = armature_obj.pose.bones[bname]
        c = pb.constraints.new('DAMPED_TRACK')
        c.target = tobj
        c.track_axis = 'TRACK_Y'
        
    bpy.ops.nla.bake(
        frame_start=f_start,
        frame_end=f_end,
        only_selected=False,
        visual_keying=True,
        clear_constraints=True,
        bake_types={'POSE'}
    )
    bpy.ops.object.mode_set(mode='OBJECT')
    
    baked = armature_obj.animation_data.action
    baked.name = clean_name
    baked_actions.append(baked)

# 6. Limpiar objetos temporales del zombie original y el rig guía
print("=== 6. LIMPIANDO OBJETOS TEMPORALES ===")
for pname in zombie_parts:
    bpy.data.objects.remove(bpy.data.objects[pname], do_unlink=True)

bpy.data.objects.remove(src_arm_obj, do_unlink=True)
bpy.data.objects.remove(head_tip, do_unlink=True)
bpy.data.objects.remove(foot_l_tip, do_unlink=True)
bpy.data.objects.remove(foot_r_tip, do_unlink=True)

# Limpiar acciones previas que no sean las horneadas
for act in list(bpy.data.actions):
    if act not in baked_actions:
        bpy.data.actions.remove(act)

# 7. Configurar NLA Tracks
print("=== 7. CREANDO NLA TRACKS PARA EXPORTACIÓN ===")
if not armature_obj.animation_data:
    armature_obj.animation_data_create()

for t in list(armature_obj.animation_data.nla_tracks):
    armature_obj.animation_data.nla_tracks.remove(t)

for act in baked_actions:
    track = armature_obj.animation_data.nla_tracks.new()
    track.name = act.name
    strip = track.strips.new(act.name, int(act.frame_range[0]), act)
    strip.name = act.name

# Acción activa por defecto: idle
act_idle = bpy.data.actions.get("idle")
if act_idle:
    armature_obj.animation_data.action = act_idle

# 8. Guardar .blend y exportar GLB
print(f"=== 8. GUARDANDO BLEND: {OUT_BLEND} ===")
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

print(f"=== 9. EXPORTANDO GLB AL PROYECTO: {OUT_GLB_PROJECT} ===")
bpy.ops.object.select_all(action='DESELECT')
zombie_mesh.select_set(True)
armature_obj.select_set(True)
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

print(">>> ¡ZOMBIE RETARGETEADO A 15 HUESOS CON ÉXITO TOTAL! <<<")
