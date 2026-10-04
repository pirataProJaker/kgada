class_name ElectricServicePillar
extends Node3D
## Mocheta / Pilar de Acometida Eléctrica CFE para Casas Procedurales.
## Estándar mexicano: Pilar de concreto/ladrillo ubicado en el lindero frontal entre dos lotes.
## En modo compartido (SHARED_DUAL):
## - Fachada frontal (hacia banqueta/calle): 2 medidores CFE (uno arriba y uno abajo).
## - Fachada trasera (hacia el interior de los predios): 2 cajas de switches / centros de carga.
## - Parte superior: Mástil metálico (tubo conduit galvanizado) con mufa de acometida aérea a 4.1m.

const ElectricMeterScript = preload("res://world/electricity/electric_meter.gd")

enum PillarMode {
	SHARED_DUAL = 0, # Compartido entre 2 casas (1 medidor arriba, 1 abajo)
	SINGLE_MONO = 1  # Mufa individual para 1 sola casa (aislada / ricos)
}

@export var pillar_mode: PillarMode = PillarMode.SHARED_DUAL
@export var house_id_top: String = "Casa_1"
@export var house_id_bottom: String = "Casa_2"

var meter_top: Node3D = null
var meter_bottom: Node3D = null

func _ready() -> void:
	_build_pillar_geometry()

func _build_pillar_geometry() -> void:
	# 1. Columna / Mocheta de Concreto y Mampostería
	var p_width := 0.38
	var p_depth := 0.32
	var p_height := 1.85

	var pillar_mesh_inst := MeshInstance3D.new()
	pillar_mesh_inst.name = "ConcretePillarBody"
	var p_box := BoxMesh.new()
	p_box.size = Vector3(p_width, p_height, p_depth)
	pillar_mesh_inst.mesh = p_box

	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.70, 0.69, 0.66) # Concreto aparente / estuco gris urbano
	p_mat.roughness = 0.95
	pillar_mesh_inst.material_override = p_mat
	pillar_mesh_inst.position = Vector3(0.0, p_height * 0.5, 0.0)
	add_child(pillar_mesh_inst)

	# 2. Base de pedestal / zapata de banqueta (saliente de 3cm para realismo)
	var base_pedestal := MeshInstance3D.new()
	base_pedestal.name = "PillarPlinth"
	var plinth_mesh := BoxMesh.new()
	plinth_mesh.size = Vector3(p_width + 0.05, 0.12, p_depth + 0.05)
	base_pedestal.mesh = plinth_mesh
	base_pedestal.material_override = p_mat
	base_pedestal.position = Vector3(0.0, 0.06, 0.0)
	add_child(base_pedestal)

	# 3. Colisión física sólida (StaticBody3D) para que el jugador o carros choquen con el pilar
	var col_body := StaticBody3D.new()
	col_body.name = "PillarCollision"
	var col_shape := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(p_width + 0.05, p_height, p_depth + 0.05)
	col_shape.shape = b_shape
	col_shape.position = Vector3(0.0, p_height * 0.5, 0.0)
	col_body.add_child(col_shape)
	add_child(col_body)

	# 4. Mástil de Acometida CFE (Tubo conduit galvanizado de 1 1/4" hasta 4.10m de altura)
	var pipe_inst := MeshInstance3D.new()
	pipe_inst.name = "ConduitPipeMast"
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 0.022
	pipe_mesh.bottom_radius = 0.022
	var mast_len := 2.45
	pipe_mesh.height = mast_len
	pipe_mesh.radial_segments = 8 # Ultra low-poly
	pipe_inst.mesh = pipe_mesh

	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.68, 0.70, 0.72) # Acero galvanizado
	pipe_mat.metallic = 0.85
	pipe_mat.roughness = 0.35
	pipe_inst.material_override = pipe_mat
	# Emerge del centro superior del pilar
	pipe_inst.position = Vector3(0.0, p_height + mast_len * 0.5, 0.0)
	add_child(pipe_inst)

	# 5. La Mufa CFE (Cabeza de servicio curvada tipo campana/pera a 4.10m)
	var mufa_top_y := p_height + mast_len
	var mufa_inst := MeshInstance3D.new()
	mufa_inst.name = "ServiceEntranceHead"
	var mufa_mesh := SphereMesh.new()
	mufa_mesh.radius = 0.05
	mufa_mesh.height = 0.08
	mufa_mesh.radial_segments = 8
	mufa_mesh.rings = 4
	mufa_inst.mesh = mufa_mesh
	mufa_inst.material_override = pipe_mat
	mufa_inst.position = Vector3(0.0, mufa_top_y, 0.02)
	add_child(mufa_inst)

	# Cables de acometida que salen de la mufa hacia la calle (2 cables negros curvados)
	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.12, 0.12, 0.12) # Aislante negro neopreno
	cable_mat.roughness = 0.8

	for cable_x in [-0.025, 0.025]:
		var drop_cable := MeshInstance3D.new()
		var c_mesh := BoxMesh.new()
		c_mesh.size = Vector3(0.015, 0.15, 0.015)
		drop_cable.mesh = c_mesh
		drop_cable.material_override = cable_mat
		drop_cable.position = Vector3(cable_x, mufa_top_y - 0.06, 0.05)
		drop_cable.rotation_degrees = Vector3(25.0, 0.0, 0.0)
		add_child(drop_cable)

	# 6. Colocar Medidores al frente (+Z) y Switches atrás (-Z)
	var front_z := (p_depth * 0.5)
	var back_z := -(p_depth * 0.5)

	if pillar_mode == PillarMode.SHARED_DUAL:
		# --- MEDIDOR SUPERIOR (ARRIBA) ---
		meter_top = ElectricMeterScript.new()
		meter_top.name = "MeterTop"
		meter_top.meter_id = "CFE-TOP-18LM"
		meter_top.assigned_house_id = house_id_top
		meter_top.installation_type = ElectricMeterScript.InstallationType.SHARED_PILLAR
		meter_top.position = Vector3(0.0, 1.48, front_z)
		add_child(meter_top)

		# Caja de switch del medidor superior (detrás del pilar a la misma altura)
		meter_top.build_switch_box(self, Vector3(0.0, 1.48, back_z), PI)

		# --- MEDIDOR INFERIOR (ABAJO) ---
		meter_bottom = ElectricMeterScript.new()
		meter_bottom.name = "MeterBottom"
		meter_bottom.meter_id = "CFE-BOT-06LM"
		meter_bottom.assigned_house_id = house_id_bottom
		meter_bottom.installation_type = ElectricMeterScript.InstallationType.SHARED_PILLAR
		meter_bottom.position = Vector3(0.0, 1.05, front_z)
		add_child(meter_bottom)

		# Caja de switch del medidor inferior (detrás del pilar a la misma altura)
		meter_bottom.build_switch_box(self, Vector3(0.0, 1.05, back_z), PI)

	else: # SINGLE_MONO (Casa rica / aislada)
		meter_top = ElectricMeterScript.new()
		meter_top.name = "MeterMono"
		meter_top.meter_id = "CFE-RES-01LM"
		meter_top.assigned_house_id = house_id_top
		meter_top.installation_type = ElectricMeterScript.InstallationType.SINGLE_PILLAR
		meter_top.position = Vector3(0.0, 1.35, front_z)
		add_child(meter_top)

		meter_top.build_switch_box(self, Vector3(0.0, 1.35, back_z), PI)
