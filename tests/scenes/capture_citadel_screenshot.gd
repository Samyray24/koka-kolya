extends SceneTree

# Cinematic Screenshot Capture for Level 4: Citadel Penthouse

var frames_waited: int = 0
var target_scene: Node = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		print("[SCREENSHOT] Loading citadel_penthouse.tscn...")
		var scene_res: PackedScene = load("res://scenes/levels/citadel_penthouse.tscn")
		if scene_res:
			target_scene = scene_res.instantiate()
			root.add_child(target_scene)

			var p_cam: Camera3D = target_scene.get_node_or_null("Player/Head/Camera3D") as Camera3D
			if p_cam:
				p_cam.current = false
			var cam := Camera3D.new()
			cam.name = "CinematicCam"
			target_scene.add_child(cam)
			# Расположим камеру в пентхаусе с видом на квантовый сервер, голограммы и вертолётную площадку
			cam.position = Vector3(-9.0, 3.8, -12.0)
			cam.look_at(Vector3(0.0, 1.8, 10.0), Vector3.UP)
			cam.current = true
			cam.make_current()
		else:
			printerr("[SCREENSHOT] Failed to load citadel_penthouse.tscn")
			quit(1)
			return true

	if frames_waited == 45:
		print("[SCREENSHOT] Capturing viewport image...")
		var img := root.get_texture().get_image()
		if img:
			var save_path := "docs/screenshots/citadel_penthouse.png"
			var err := img.save_png(save_path)
			if err == OK:
				print("[SCREENSHOT] Successfully saved screenshot to: %s" % save_path)
		quit(0)
		return true

	return false
