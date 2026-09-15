extends Node

func _ready() -> void:
	print("--- TESTING ZOMBIE GAMEPLAY LOGIC ---")
	var zombie_scene := load("res://world/mobs/zombie.tscn") as PackedScene
	var zombie := zombie_scene.instantiate() as CharacterBody3D
	add_child(zombie)
	zombie.global_position = Vector3(0, 0, 0)
	
	# Create a mock player node in "players" group
	var mock_player := Node3D.new()
	mock_player.name = "MockPlayer"
	mock_player.add_to_group("players")
	add_child(mock_player)
	mock_player.global_position = Vector3(5, 0, 0)
	
	await get_tree().process_frame
	await get_tree().physics_frame
	
	# Test 1: Near player check
	zombie.call("_update_lod")
	print("Test 1 - Near Player: ", zombie.get("_is_near_player"), " (expected true)")
	assert(zombie.get("_is_near_player") == true)
	
	# Test 2: Far player check
	mock_player.global_position = Vector3(50, 0, 0)
	zombie.call("_update_lod")
	print("Test 2 - Far Player: ", zombie.get("_is_far_player"), " (expected true)")
	assert(zombie.get("_is_far_player") == true)
	
	# Test 3: Damage and death
	mock_player.global_position = Vector3(2, 0, 0)
	zombie.call("_update_lod")
	print("Initial health: ", zombie.get("_health"))
	zombie.take_damage(30.0)
	print("Health after 30 damage: ", zombie.get("_health"), " (expected 30.0)")
	assert(zombie.get("_health") == 30.0)
	
	# Kill zombie
	zombie.take_damage(30.0)
	print("Zombie dead: ", zombie.get("_dead"), " (expected true)")
	assert(zombie.get("_dead") == true)
	print("Zombie current animation: ", zombie.get("_current_anim"), " (expected die)")
	assert(zombie.get("_current_anim") == "die")
	
	print("=== ALL ZOMBIE GAMEPLAY TESTS PASSED ===")
	get_tree().quit(0)
