extends SceneTree

# Automated Screenshot Capture for Red Line Plant (Stage 4 Vertical Slice)

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
			
			var cam := Camera3D.new()
			cam.name = "CinematicCam"
			root.add_child(cam)
			cam.position = Vector3(-6.8, 2.2, 53.5)
			cam.look_at(Vector3(-1.0, 1.2, 49.0), Vector3.UP)
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
			else:
				printerr("[SCREENSHOT] Failed to save screenshot, error code: %d" % err)
		quit(0)
		return true

	return false