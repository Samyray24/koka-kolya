extends SceneTree

# Automated Screenshot Capture for AI Arena

var frames_waited: int = 0
var target_scene: Node = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		print("[SCREENSHOT] Loading ai_arena.tscn after autoloads initialization...")
		var scene_res: PackedScene = load("res://scenes/testlabs/ai_arena.tscn")
		if scene_res:
			target_scene = scene_res.instantiate()
			root.add_child(target_scene)
		else:
			printerr("[SCREENSHOT] Failed to load ai_arena.tscn")
			quit(1)
			return true

	if frames_waited == 45:
		print("[SCREENSHOT] Capturing viewport image...")
		var img := root.get_texture().get_image()
		if img:
			var save_path := "docs/screenshots/ai_arena.png"
			var err := img.save_png(save_path)
			if err == OK:
				print("[SCREENSHOT] Successfully saved screenshot to: %s" % save_path)
			else:
				printerr("[SCREENSHOT] Failed to save screenshot, error code: %d" % err)
		quit(0)
		return true

	return false
