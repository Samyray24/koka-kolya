extends SceneTree

# Automated Screenshot Capture for Old District (Stage 3 First Playable)

var frames_waited: int = 0
var target_scene: Node = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		print("[SCREENSHOT] Loading old_district.tscn...")
		var scene_res: PackedScene = load("res://scenes/levels/old_district.tscn")
		if scene_res:
			target_scene = scene_res.instantiate()
			root.add_child(target_scene)
			var p_cam: Camera3D = target_scene.get_node_or_null("Player/Head/Camera3D") as Camera3D
			if p_cam:
				p_cam.make_current()
			var player: Node3D = target_scene.get_node_or_null("Player") as Node3D
			if player:
				player.look_at(Vector3(3, 1.0, 45), Vector3.UP)
		else:
			printerr("[SCREENSHOT] Failed to load old_district.tscn")
			quit(1)
			return true

	if frames_waited == 45:
		print("[SCREENSHOT] Capturing viewport image...")
		var img := root.get_texture().get_image()
		if img:
			var save_path := "docs/screenshots/old_district.png"
			var err := img.save_png(save_path)
			if err == OK:
				print("[SCREENSHOT] Successfully saved screenshot to: %s" % save_path)
			else:
				printerr("[SCREENSHOT] Failed to save screenshot, error code: %d" % err)
		quit(0)
		return true

	return false