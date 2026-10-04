extends SceneTree

func _init() -> void:
	var glb_path := "res://assets/characters/psx_humanoid.glb"
	var scn: PackedScene = load(glb_path)
	var inst := scn.instantiate()
	var ap := inst.find_children("*", "AnimationPlayer")[0] as AnimationPlayer
	for anim_name in ap.get_animation_list():
		var anim: Animation = ap.get_animation(anim_name)
		print("Animation: ", anim_name, " | Length: ", anim.length, "s | Track count: ", anim.get_track_count())
		for t in range(mini(5, anim.get_track_count())):
			print("   Track %d: path=%s, key_count=%d" % [t, anim.track_get_path(t), anim.track_get_key_count(t)])
	quit()
