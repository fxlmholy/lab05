extends SceneTree
# Renders a contact sheet of models: godot --path . --script tools/preview_models.gd -- out.png file1 file2 ...
func _init():
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); root.add_child(sun)
	var n := args.size() - 1
	var cols := int(ceil(sqrt(n)))
	for i in n:
		var p: String = args[i + 1]
		var s: Node3D = load(p).instantiate()
		root.add_child(s)
		s.position = Vector3((i % cols) * 7.0, 0, (i / cols) * 7.0)
		var ap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
		if ap and args.has("--anim"): pass
		var l := Label3D.new(); l.text = p.get_file().get_basename(); l.font_size = 96; l.pixel_size = 0.01
		l.position = s.position + Vector3(0, -0.6, 2.5); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color.BLACK
		root.add_child(l)
	var cam := Camera3D.new(); root.add_child(cam)
	var c := Vector3((cols - 1) * 3.5, 0, ((n - 1) / cols) * 3.5)
	cam.look_at_from_position(c + Vector3(0, cols * 4.5, cols * 6.5), c + Vector3(0, 1, 0))
	cam.fov = 50
	for f in 10: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
