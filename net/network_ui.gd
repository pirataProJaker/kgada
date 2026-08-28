extends CanvasLayer

@onready var host_button: Button = $Panel/VBox/HostButton
@onready var join_button: Button = $Panel/VBox/JoinRow/JoinButton
@onready var address_input: LineEdit = $Panel/VBox/JoinRow/AddressInput
@onready var status_label: Label = $Panel/VBox/StatusLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.connection_status_changed.connect(_on_status_changed)


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	_disable_controls()


func _on_join_pressed() -> void:
	var address := address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	NetworkManager.join_game(address)
	_disable_controls()


func _on_status_changed(status: String) -> void:
	status_label.text = status


func _disable_controls() -> void:
	host_button.disabled = true
	join_button.disabled = true
	address_input.editable = false
