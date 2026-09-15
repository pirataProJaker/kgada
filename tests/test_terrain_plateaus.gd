extends Node

func _ready() -> void:
	print("--- TESTING FLAT STEPPED PLATEAU TERRAIN ---")
	assert(ClassDB.class_exists("TerrainGenerator"), "TerrainGenerator class must exist in ClassDB")
	var generator = ClassDB.instantiate("TerrainGenerator")
	assert(generator != null, "Failed to instantiate TerrainGenerator")
	
	var world_seed := 1
	var samples_5m := 0
	var samples_10m := 0
	var samples_15m := 0
	var samples_20m := 0
	var samples_transitions := 0
	
	# Sample along a 4000m transect (400 samples spaced 10m apart)
	for i in range(400):
		var x: float = float(i) * 10.0
		var h: float = generator.call("sample_height", world_seed, x, x * 0.5)
		
		if is_equal_approx(h, 5.0):
			samples_5m += 1
		elif is_equal_approx(h, 10.0):
			samples_10m += 1
		elif is_equal_approx(h, 15.0):
			samples_15m += 1
		elif is_equal_approx(h, 20.0):
			samples_20m += 1
		else:
			samples_transitions += 1
			
	print("Plateau samples breakdown over 4000m:")
	print(" - 5.0m Valley samples: ", samples_5m)
	print(" - 10.0m Plains samples: ", samples_10m)
	print(" - 15.0m Plateau samples: ", samples_15m)
	print(" - 20.0m Highlands samples: ", samples_20m)
	print(" - Transition ramp samples: ", samples_transitions)
	
	# Verify that the majority of samples are completely flat plateaus
	var flat_samples := samples_5m + samples_10m + samples_15m + samples_20m
	print("Total perfectly flat samples: %d / 400 (%.1f%%)" % [flat_samples, float(flat_samples) / 4.0])
	assert(flat_samples >= 300, "At least 75% of terrain points should be on flat plateaus")
	
	# Verify chunk generation
	var chunk_data: Dictionary = generator.call(
		"generate_chunk",
		17, 2.5, world_seed, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0
	)
	assert(chunk_data.has("vertices"), "Chunk data must contain vertices")
	assert(chunk_data.has("normals"), "Chunk data must contain normals")
	assert(chunk_data.has("indices"), "Chunk data must contain indices")
	var verts: PackedVector3Array = chunk_data["vertices"]
	print("Generated chunk vertex count: ", verts.size())
	assert(verts.size() > 0, "Chunk should have non-empty vertices")
	
	print("=== ALL TERRAIN PLATEAU TESTS PASSED ===")
	get_tree().quit(0)
