extends SceneTree

# Builder for 15 AAA PBR StandardMaterial3D resources in Godot 4
var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		_build_materials()
		quit(0)
		return true
	return false

func _build_materials() -> void:
	print("==================================================================")
	print(">>> СБОРКА 15 AAA PBR МАТЕРИАЛОВ (StandardMaterial3D) <<<")
	print("==================================================================")

	var mats = [
		"road_wet_asphalt",
		"road_cyber_highway",
		"concrete_cyber_facade",
		"metal_industrial_diamond",
		"metal_rust_plates",
		"metal_corrugated_slum",
		"meridian_white_marble",
		"meridian_titanium_wall",
		"neon_hologram_grid",
		"van_livery_rebel",
		"van_livery_cyber",
		"van_livery_chrome",
		"van_livery_rust",
		"underground_brick_grunge",
		"sci_fi_server_rack"
	]

	var base_tex_dir := "res://assets/textures/pbr/"
	var out_mat_dir := "res://assets/materials/"

	for m_name: String in mats:
		var mat := StandardMaterial3D.new()
		mat.resource_name = m_name

		# 1. Albedo
		var alb_path: String = base_tex_dir + m_name + "_albedo.png"
		var tex_alb := _load_texture(alb_path)
		if tex_alb:
			mat.albedo_texture = tex_alb

		# 2. Normal
		var norm_path: String = base_tex_dir + m_name + "_normal.png"
		var tex_norm := _load_texture(norm_path)
		if tex_norm:
			mat.normal_enabled = true
			mat.normal_texture = tex_norm

		# 3. Roughness
		var rough_path: String = base_tex_dir + m_name + "_roughness.png"
		var tex_rough := _load_texture(rough_path)
		if tex_rough:
			mat.roughness_texture = tex_rough

		# 4. Metallic
		var met_path: String = base_tex_dir + m_name + "_metallic.png"
		var tex_met := _load_texture(met_path)
		if tex_met:
			mat.metallic_texture = tex_met

		# 5. Emission
		var em_path: String = base_tex_dir + m_name + "_emission.png"
		var tex_em := _load_texture(em_path)
		if tex_em:
			mat.emission_enabled = true
			mat.emission_texture = tex_em
			mat.emission_energy_multiplier = 3.0

		var out_file: String = out_mat_dir + "mat_" + m_name + ".tres"
		var err := ResourceSaver.save(mat, out_file)
		print("Material created: ", out_file, " (code: ", err, ")")

	print("==================================================================")
	print(">>> ВСЕ 15 AAA PBR МАТЕРИАЛОВ УСПЕШНО СОБРАНЫ <<<")
	print("==================================================================")

func _load_texture(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	var global_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_p):
		return load(res_path) as Texture2D
	return null
