extends SceneTree

var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_convert_all_models()
		quit(0)
		return true
	return false

func _convert_all_models() -> void:
	print("--- Batch Converting GLB Models to PackedScenes ---")
	var out_dir = "res://assets/scenes_3d/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var models_path = ProjectSettings.globalize_path("res://assets/models")
	var glb_files: Array[String] = []

	_find_glb_recursive(models_path, glb_files)
	print("Found %d GLB files to convert." % glb_files.size())

	for file_path in glb_files:
		var base_name = file_path.get_file().get_basename()
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		var err = gltf.append_from_file(file_path, state)
		if err != OK:
			printerr("Failed to append GLTF: ", file_path, " err: ", err)
			continue

		var root_node = gltf.generate_scene(state)
		if not root_node:
			printerr("Failed to generate scene for: ", file_path)
			continue

		# Automatically generate trimesh static collision for buildings and roads
		if "building" in base_name or "road" in base_name or "pavement" in base_name or "brick" in base_name:
			_add_trimesh_collision(root_node)

		var packed = PackedScene.new()
		packed.pack(root_node)
		var tscn_path = out_dir + base_name + ".tscn"
		var save_err = ResourceSaver.save(packed, tscn_path)
		print("Converted: ", base_name, " -> ", tscn_path, " (err: ", save_err, ")")
		root_node.free()

	print("--- All GLB models successfully converted to PackedScenes! ---")

func _find_glb_recursive(dir_path: String, results: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if item != "." and item != "..":
			var full_path = dir_path + "/" + item
			if dir.current_is_dir():
				_find_glb_recursive(full_path, results)
			elif item.ends_with(".glb"):
				results.append(full_path)
		item = dir.get_next()
	dir.list_dir_end()

func _add_trimesh_collision(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			child.create_trimesh_collision()
		_add_trimesh_collision(child)

