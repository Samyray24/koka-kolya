extends SceneTree

var executed: bool = false

func _process(_delta: float) -> bool:
	if executed:
		return true
	executed = true

	print("--- Setting up PBR Materials ---")
	var mat_defs = {
		"asphalt": {
			"color": "res://assets/textures/pbr/asphalt/asphalt_color.jpg",
			"normal": "res://assets/textures/pbr/asphalt/asphalt_normal.jpg",
			"roughness": "res://assets/textures/pbr/asphalt/asphalt_roughness.jpg",
			"triplanar": true,
			"uv_scale": Vector3(0.2, 0.2, 0.2),
			"metallic": 0.0
		},
		"brick": {
			"color": "res://assets/textures/pbr/brick/brick_color.jpg",
			"normal": "res://assets/textures/pbr/brick/brick_normal.jpg",
			"roughness": "res://assets/textures/pbr/brick/brick_roughness.jpg",
			"triplanar": true,
			"uv_scale": Vector3(0.3, 0.3, 0.3),
			"metallic": 0.0
		},
		"concrete": {
			"color": "res://assets/textures/pbr/concrete/concrete_color.jpg",
			"normal": "res://assets/textures/pbr/concrete/concrete_normal.jpg",
			"roughness": "res://assets/textures/pbr/concrete/concrete_roughness.jpg",
			"triplanar": true,
			"uv_scale": Vector3(0.25, 0.25, 0.25),
			"metallic": 0.0
		},
		"metal": {
			"color": "res://assets/textures/pbr/metal/metal_color.jpg",
			"normal": "res://assets/textures/pbr/metal/metal_normal.jpg",
			"roughness": "res://assets/textures/pbr/metal/metal_roughness.jpg",
			"triplanar": true,
			"uv_scale": Vector3(0.5, 0.5, 0.5),
			"metallic": 0.8
		},
		"paving": {
			"color": "res://assets/textures/pbr/paving/paving_color.jpg",
			"normal": "res://assets/textures/pbr/paving/paving_normal.jpg",
			"roughness": "res://assets/textures/pbr/paving/paving_roughness.jpg",
			"triplanar": true,
			"uv_scale": Vector3(0.35, 0.35, 0.35),
			"metallic": 0.0
		},
		"wood": {
			"color": "res://assets/textures/pbr/wood/wood_color.jpg",
			"normal": "res://assets/textures/pbr/wood/wood_normal.jpg",
			"roughness": "res://assets/textures/pbr/wood/wood_roughness.jpg",
			"triplanar": true,
			"uv_scale": Vector3(0.5, 0.5, 0.5),
			"metallic": 0.0
		}
	}
	
	DirAccess.make_dir_recursive_absolute("res://assets/materials")
	
	for name in mat_defs:
		var def = mat_defs[name]
		var mat = StandardMaterial3D.new()
		
		var col_img = Image.load_from_file(ProjectSettings.globalize_path(def["color"]))
		if col_img:
			var col_tex = ImageTexture.create_from_image(col_img)
			mat.albedo_texture = col_tex
			
		var norm_img = Image.load_from_file(ProjectSettings.globalize_path(def["normal"]))
		if norm_img:
			var norm_tex = ImageTexture.create_from_image(norm_img)
			mat.normal_enabled = true
			mat.normal_scale = 1.0
			mat.normal_texture = norm_tex
			
		var rgh_img = Image.load_from_file(ProjectSettings.globalize_path(def["roughness"]))
		if rgh_img:
			var rgh_tex = ImageTexture.create_from_image(rgh_img)
			mat.roughness_texture = rgh_tex
			
		mat.uv1_triplanar = def["triplanar"]
		mat.uv1_scale = def["uv_scale"]
		mat.metallic = def["metallic"]
		
		var out_path = "res://assets/materials/mat_" + name + ".tres"
		var err = ResourceSaver.save(mat, out_path)
		print("Saved material ", out_path, " -> err: ", err)
		
	print("--- PBR Materials Setup Complete ---")
	quit(0)
	return true
