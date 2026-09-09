extends SceneTree

var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		_do_convert()
		quit(0)
		return true
	return false

func _do_convert() -> void:
	var files = [
		"res://assets/textures/characters/guard_armor_albedo.png",
		"res://assets/textures/characters/guard_armor_normal.png",
		"res://assets/textures/characters/guard_armor_roughness.png",
		"res://assets/textures/characters/kolya_jacket_albedo.png",
		"res://assets/textures/characters/kolya_jacket_normal.png",
		"res://assets/textures/characters/kolya_jacket_roughness.png",
		"res://assets/textures/characters/drone_chassis_albedo.png",
		"res://assets/textures/characters/drone_chassis_normal.png",
		"res://assets/textures/characters/drone_chassis_roughness.png",
		"res://assets/textures/environment/terrain_ground_albedo.png",
		"res://assets/textures/environment/terrain_ground_normal.png",
		"res://assets/textures/environment/terrain_ground_roughness.png",
		"res://assets/textures/environment/neon_billboard_freedom.png"
	]
	for f in files:
		var global_p: String = ProjectSettings.globalize_path(f)
		print("Attempting to load: ", global_p)
		var img := Image.load_from_file(global_p)
		if img:
			var tex := ImageTexture.create_from_image(img)
			var out_path: String = f.replace(".png", ".tres")
			var err: int = ResourceSaver.save(tex, out_path)
			print("SUCCESS: ", out_path, " code=", err)
		else:
			print("FAIL TO LOAD: ", global_p)
