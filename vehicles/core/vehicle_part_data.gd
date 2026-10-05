class_name VehiclePartData
extends Resource

## Recurso de datos para piezas modulares de vehículos (Play Sector X)

enum SlotType {
	NONE,
	WHEEL_FL,
	WHEEL_FR,
	WHEEL_RL,
	WHEEL_RR,
	DOOR_FL,
	DOOR_FR,
	DOOR_RL,
	DOOR_RR,
	HOOD,
	TRUNK,
	ENGINE_BAY,
	BATTERY,
	RADIATOR,
	OIL_DIPSTICK
}

@export var part_id: String = ""
@export var display_name: String = ""
@export var slot_type: SlotType = SlotType.NONE
@export var compatible_models: Array[String] = ["universal"]
@export var mass_kg: float = 10.0
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var wear_pct: float = 0.0 # 0.0 = Nuevo, 1.0 = Desgastado/chatarra

## Parámetros específicos para motores
@export_group("Engine Properties")
@export var horse_power: float = 90.0
@export var max_rpm: float = 6000.0
@export var oil_level: float = 1.0 # 0.0 = Vacío, 1.0 = Lleno
@export var oil_quality: float = 1.0 # 1.0 = Limpio (dorado), 0.0 = Quemado (negro)
@export var temperature: float = 20.0 # Grados C

## Parámetros específicos para ruedas
@export_group("Wheel Properties")
@export var wheel_radius: float = 0.29
@export var friction_slip: float = 1.05
@export var is_flat: bool = false


## Verifica si esta pieza es compatible con un modelo de auto dado
func is_compatible_with(model_id: String) -> bool:
	if compatible_models.has("universal"):
		return true
	return compatible_models.has(model_id)
