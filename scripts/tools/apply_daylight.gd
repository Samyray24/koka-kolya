extends SceneTree

var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_apply_bright_daylight()
		quit(0)
		return true
	return false

func _apply_bright_daylight() -> void:
	print("--- Applying Bright Daylight & Crisply Lit Environment ---")
	
	# 1. Update EnvironmentManager time to 14:00 (midday)
	var em_file = FileAccess.open("res://scripts/core/environment_manager.gd", FileAccess.READ)
	if em_file:
		var em_code = em_file.get_as_text()
		em_file.close()
		em_code = em_code.replace("var time_of_day: float = 21.5", "var time_of_day: float = 14.0")
		var em_out = FileAccess.open("res://scripts/core/environment_manager.gd", FileAccess.WRITE)
		em_out.store_string(em_code)
		em_out.close()
		print("[OK] Set EnvironmentManager default time to 14:00")

	# 2. Update OldDistrict Scene
	var scene_res: PackedScene = load("res://scenes/levels/old_district.tscn")
	var root_node = scene_res.instantiate()

	# Sun: pitch -48 deg, yaw 15 deg (shining down and forward, illuminating all faces)
	var sun: DirectionalLight3D = root_node.get_node_or_null("SunLight")
	if sun:
		sun.rotation_degrees = Vector3(-48, 15, 0)
		sun.light_color = Color(1.0, 0.98, 0.92)
		sun.light_energy = 3.2
		sun.shadow_enabled = true
		sun.shadow_bias = 0.03
		print("[OK] Sun configured for bright daylight over the shoulder")

	# WorldEnvironment
	var env_node: WorldEnvironment = root_node.get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		# Sky
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var psky = env.sky.sky_material as ProceduralSkyMaterial
			psky.sky_top_color = Color(0.32, 0.52, 0.82, 1.0)
			psky.sky_horizon_color = Color(0.82, 0.88, 0.94, 1.0)
			psky.ground_bottom_color = Color(0.25, 0.28, 0.32, 1.0)
			psky.ground_horizon_color = Color(0.78, 0.82, 0.88, 1.0)
			psky.sun_angle_max = 30.0

		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_color = Color(0.85, 0.90, 0.95, 1.0)
		env.ambient_light_energy = 2.2
		env.ambient_light_sky_contribution = 0.85
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.2
		env.tonemap_white = 1.0
		env.glow_enabled = true
		env.glow_intensity = 0.3
		env.glow_bloom = 0.05
		print("[OK] Environment tuned for clear day lighting")

	# Drone position (off to the side, hovering comfortably)
	var drone: Node3D = root_node.get_node_or_null("BubbleDrone")
	if drone:
		drone.position = Vector3(2.2, 1.8, 47.5)

	# Save scene
	var packed = PackedScene.new()
	packed.pack(root_node)
	ResourceSaver.save(packed, "res://scenes/levels/old_district.tscn")
	print("[OK] Saved brightly lit old_district.tscn")
	root_node.free()

