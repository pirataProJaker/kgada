class_name ElectricMeter
extends Node3D

const CityTextureManager = preload("res://world/city/city_texture_manager.gd")
## Medidor Eléctrico Digital CFE (Bifásico/Monofásico bidireccional low-poly)
## Representa la unidad de medición de energía y su correspondiente interruptor de seguridad (switch/fusibles).
## Diseñado para interacción futura (medir consumo en tiempo real de la casa y cortar/restablecer la luz).

signal switch_toggled(is_on: bool)

enum InstallationType {
	SHARED_PILLAR = 0, # Montado en pilar compartido entre 2 casas (arriba o abajo)
	SINGLE_PILLAR = 1, # Montado en mufa individual (casa aislada o de ricos)
	WALL_EMBEDDED = 2  # Incrustado directamente en la pared de la fachada
}

@export var meter_id: String = "CFE-N062EG-18LM"
@export var assigned_house_id: String = ""
@export var assigned_house_node: NodePath = NodePath()
@export var installation_type: InstallationType = InstallationType.SHARED_PILLAR

## Lectura acumulada de energía (kWh) para simulación futura
@export var kwh_reading: float = 1420.5

## Consumo instantáneo en Watts (ej: 0 si el switch está abajo, 850W con refri y tele prendidos)
@export var current_power_draw_watts: float = 0.0

## Estado del interruptor general de la casa (true = encendido / conectado, false = cortado / bajada la palanca)
@export var switch_closed: bool = true:
	set(val):
		switch_closed = val
		_update_switch_visual()
		switch_toggled.emit(switch_closed)

var _switch_lever_pivot: Node3D = null
var _meter_mesh_node: Node3D = null
var _switch_box_node: Node3D = null

func _ready() -> void:
	_build_meter_visuals()
	_update_switch_visual()

## Alterna la palanca del interruptor (apaga o prende la luz de la casa asignada)
func toggle_switch() -> void:
	self.switch_closed = not self.switch_closed
	print("[ElectricMeter %s] Switch alternado -> %s (Casa: %s)" % [
		meter_id, "CONECTADO" if switch_closed else "CORTADO", assigned_house_id
	])

## Construye la geometría low-poly del medidor CFE (cilindro 12 lados + collarín metálico + frontal de cristal)
func _build_meter_visuals() -> void:
	# 1. Base del Enchufe Redondo (Aro metálico donde se clava el medidor al muro o caja)
	var collar := MeshInstance3D.new()
	collar.name = "SocketBaseCollar"
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.096
	collar_mesh.bottom_radius = 0.096
	collar_mesh.height = 0.020
	collar_mesh.radial_segments = 12
	collar.mesh = collar_mesh
	
	var collar_mat := StandardMaterial3D.new()
	collar_mat.albedo_color = Color(0.28, 0.30, 0.32) # Metal galvanizado oscuro
	collar_mat.metallic = 0.70
	collar_mat.roughness = 0.40
	collar.material_override = collar_mat
	collar.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	collar.position = Vector3(0.0, 0.0, 0.010)
	add_child(collar)

	# 2. Cuerpo del Medidor CFE (Cilindro low-poly de 12 lados de policarbonato gris)
	var cylinder := MeshInstance3D.new()
	cylinder.name = "MeterCylinderBody"
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.090
	cyl_mesh.bottom_radius = 0.090
	cyl_mesh.height = 0.065
	cyl_mesh.radial_segments = 12
	cylinder.mesh = cyl_mesh
	
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.82, 0.83, 0.85) # Plástico gris claro CFE
	body_mat.roughness = 0.55
	cylinder.material_override = body_mat
	cylinder.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	cylinder.position = Vector3(0.0, 0.0, 0.045)
	add_child(cylinder)

	# 3. Carátula Frontal de Cristal con Textura Digital CFE
	var face := MeshInstance3D.new()
	face.name = "MeterFaceGlass"
	var q_mesh := QuadMesh.new()
	q_mesh.size = Vector2(0.18, 0.18)
	face.mesh = q_mesh

	face.material_override = CityTextureManager.get_meter_material()
	face.position = Vector3(0.0, 0.0, 0.078) # Ligeramente por delante de la tapa del cilindro
	add_child(face)

	# 4. Aro de sellado / cerrojo de seguridad CFE (plomo / aro metálico perimetral)
	var rim := MeshInstance3D.new()
	rim.name = "SecurityRing"
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.092
	rim_mesh.bottom_radius = 0.092
	rim_mesh.height = 0.012
	rim_mesh.radial_segments = 12
	rim.mesh = rim_mesh
	
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.72, 0.74, 0.76) # Aro de acero inoxidable
	rim_mat.metallic = 0.85
	rim_mat.roughness = 0.30
	rim.material_override = rim_mat
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	rim.position = Vector3(0.0, 0.0, 0.065)
	add_child(rim)

## Construye la caja de switch de seguridad (en la parte trasera del pilar o junto al medidor)
func build_switch_box(parent_node: Node3D, local_pos: Vector3, local_rot_y: float = 0.0) -> Node3D:
	var switch_root := Node3D.new()
	switch_root.name = "SwitchBox_%s" % assigned_house_id
	switch_root.position = local_pos
	switch_root.rotation.y = local_rot_y
	parent_node.add_child(switch_root)

	# 1. Caja metálica gabinete Square D / IUSA (Gabinete NEMA 1 estándar mexicano)
	var box_inst := MeshInstance3D.new()
	box_inst.name = "EnclosureBox"
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.20, 0.28, 0.10)
	box_inst.mesh = b_mesh
	
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.42, 0.44, 0.46) # Pintura gris martillada epóxica
	box_mat.metallic = 0.50
	box_mat.roughness = 0.65
	box_inst.material_override = box_mat
	box_inst.position = Vector3(0.0, 0.0, 0.05)
	switch_root.add_child(box_inst)

	# 2. Tapa frontal abatible con bisagras y ranura
	var door_inst := MeshInstance3D.new()
	door_inst.name = "CabinetDoor"
	var d_mesh := BoxMesh.new()
	d_mesh.size = Vector3(0.185, 0.265, 0.015)
	door_inst.mesh = d_mesh
	door_inst.material_override = box_mat
	door_inst.position = Vector3(0.0, 0.0, 0.105)
	switch_root.add_child(door_inst)

	# 3. Etiqueta frontal de advertencia (Triángulo amarillo de Alta Tensión / Peligro 220V)
	var label_mesh := MeshInstance3D.new()
	label_mesh.name = "WarningDecal"
	var q_label := QuadMesh.new()
	q_label.size = Vector2(0.06, 0.06)
	label_mesh.mesh = q_label
	var lbl_mat := StandardMaterial3D.new()
	lbl_mat.albedo_color = Color(0.95, 0.75, 0.10) # Amarillo advertencia
	lbl_mat.roughness = 0.5
	label_mesh.material_override = lbl_mat
	label_mesh.position = Vector3(0.0, 0.03, 0.113)
	switch_root.add_child(label_mesh)

	# 4. Palanca exterior de seguridad (Switch de navajas con manija lateral)
	_switch_lever_pivot = Node3D.new()
	_switch_lever_pivot.name = "LeverPivot"
	_switch_lever_pivot.position = Vector3(0.105, 0.02, 0.05) # Costado derecho de la caja
	switch_root.add_child(_switch_lever_pivot)

	var arm := MeshInstance3D.new()
	arm.name = "LeverArm"
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.012, 0.055, 0.012)
	arm.mesh = arm_mesh
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.20, 0.20, 0.20)
	arm.material_override = arm_mat
	arm.position = Vector3(0.008, 0.025, 0.0)
	_switch_lever_pivot.add_child(arm)

	# Mango rojo de la palanca
	var handle := MeshInstance3D.new()
	handle.name = "HandleGrip"
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.018, 0.022, 0.018)
	handle.mesh = h_mesh
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.85, 0.15, 0.10) # Rojo CFE
	h_mat.roughness = 0.40
	handle.material_override = h_mat
	handle.position = Vector3(0.008, 0.055, 0.0)
	_switch_lever_pivot.add_child(handle)

	_update_switch_visual()
	return switch_root

func _update_switch_visual() -> void:
	if _switch_lever_pivot != null:
		# Palanca ARRIBA (+35°) = Conectado / Luz activa
		# Palanca ABAJO (-35°) = Cortado / Sin energía
		var target_angle := 35.0 if switch_closed else -35.0
		_switch_lever_pivot.rotation_degrees.z = target_angle
