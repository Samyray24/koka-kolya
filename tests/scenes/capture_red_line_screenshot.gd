extends SceneTree

# Cinematic Screenshot Capture for Level 2: Red Line Plant

var frames_waited: int = 0
var target_scene: Node = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		print("[SCREENSHOT] Loading red_line_plant.tscn...")
		var scene_res: PackedScene = load("res://scenes/levels/red_line_plant.tscn")
		if scene_res:
			target_scene = scene_res.instantiate()
			root.add_child(target_scene)

			var p_cam: Camera3D = target_scene.get_node_or_null("Player/Head/Camera3D") as Camera3D
			if p_cam:
				p_cam.current = false
			var cam := Camera3D.new()
			cam.name = "CinematicCam"
			target_scene.add_child(cam)
			# Расположим камеру с приподнятого ракурса с видом на ворота, двор, завод и сиропную башню
			cam.position = Vector3(14.0, 8.5, 20.0)
			cam.look_at(Vector3(0.0, 4.0, -35.0), Vector3.UP)
			cam.current = true
			cam.make_current()
		else:
			printerr("[SCREENSHOT] Failed to load red_line_plant.tscn")
			quit(1)
			return true

	if frames_waited == 45:
		print("[SCREENSHOT] Capturing viewport image...")
		var img := root.get_texture().get_image()
		if img:
			var save_path := "docs/screenshots/red_line_plant.png"
			var err := img.save_png(save_path)
			if err == OK:
				print("[SCREENSHOT] Successfully saved screenshot to: %s" % save_path)
		quit(0)
		return true

	return false
