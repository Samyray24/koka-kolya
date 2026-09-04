extends SceneTree

# Automated Screenshot Capture for City Highway (Stage 6 Open World & Campaign)

var frames_waited: int = 0
var target_scene: Node = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		print("[SCREENSHOT] Loading city_highway.tscn...")
		var scene_res: PackedScene = load("res://scenes/levels/city_highway.tscn")
		if scene_res:
			target_scene = scene_res.instantiate()
			root.add_child(target_scene)

			var cam := Camera3D.new()
			cam.name = "CinematicCam"
			root.add_child(cam)
			cam.position = Vector3(6.5, 2.6, 79.5)
			cam.look_at(Vector3(1.0, 1.3, 72.0), Vector3.UP)
			cam.make_current()
		else:
			printerr("[SCREENSHOT] Failed to load city_highway.tscn")
			quit(1)
			return true

	if frames_waited == 45:
		print("[SCREENSHOT] Capturing viewport image...")
		var img := root.get_texture().get_image()
		if img:
			var save_path := "docs/screenshots/city_highway.png"
			var err := img.save_png(save_path)
			if err == OK:
				print("[SCREENSHOT] Successfully saved screenshot to: %s" % save_path)
			else:
				printerr("[SCREENSHOT] Failed to save screenshot, error code: %d" % err)
		quit(0)
		return true

	return false