extends SceneTree

# Cinematic Screenshot Capture for Level 3: City Highway
var frames_waited: int = 0
var target_scene: Node = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		print('[SCREENSHOT] Loading city_highway.tscn...')
		var scene_res: PackedScene = load('res://scenes/levels/city_highway.tscn')
		if scene_res:
			target_scene = scene_res.instantiate()
			root.add_child(target_scene)

			var p_cam = target_scene.get_node_or_null('Player/Head/Camera3D')
			if p_cam:
				p_cam.set('current', false)
			var cam := Camera3D.new()
			cam.name = 'CinematicCam'
			target_scene.add_child(cam)
			cam.position = Vector3(5.0, 5.5, 60.0)
			cam.look_at(Vector3(0.0, 2.0, 20.0), Vector3.UP)
			cam.current = true
			cam.make_current()
		else:
			printerr('[SCREENSHOT] Failed to load city_highway.tscn')
			quit(1)
			return true

	if frames_waited == 45:
		print('[SCREENSHOT] Capturing viewport image...')
		var img := root.get_texture().get_image()
		if img:
			var save_path := ProjectSettings.globalize_path('res://docs/screenshots/city_highway.png')
			var err := img.save_png(save_path)
			print('[SCREENSHOT] Saved to: ', save_path, ' err=', err)
		quit(0)
		return true

	return false
