extends Node

# Test driver: loads a scene, runs a timed script of inputs, saves screenshots.
# godot --path . res://tools/shot.tscn -- --scene=res://Scenes/Levels/Level1.tscn "1:shot:shots/a.png" "1.2:press:jump" "1.4:release:jump" "6:quit"
# Steps: <time>:shot:<file> | press:<action> | release:<action> | tp:x,y,z | cam:yaw,pitch | print | quit

var steps := []
var grid_imgs: Array[Image] = []
var t := 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.substr(8)
		else:
			var p := a.split(":", true, 2)
			steps.append([float(p[0]), p[1], p[2] if p.size() > 2 else ""])
	steps.sort_custom(func(x, y): return x[0] < y[0])
	var s: Node = load(scene).instantiate()
	get_tree().root.add_child.call_deferred(s)
	get_tree().set_deferred("current_scene", s)

func _process(delta):
	t += delta
	while steps.size() > 0 and steps[0][0] <= t:
		var st = steps.pop_front()
		_run(st[1], st[2])

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("Player")

func _run(cmd: String, arg: String):
	match cmd:
		"shot":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://" + arg)
			print("SHOT ", arg)
		"g":
			# grab a half-size frame for a contact sheet written by "grid"
			await RenderingServer.frame_post_draw
			var im := get_viewport().get_texture().get_image()
			im.resize(im.get_width() / 2, im.get_height() / 2)
			grid_imgs.append(im)
		"grid":
			var w := grid_imgs[0].get_width()
			var h := grid_imgs[0].get_height()
			var rows := int(ceil(grid_imgs.size() / 2.0))
			var out := Image.create(w * 2, h * rows, false, grid_imgs[0].get_format())
			for i in grid_imgs.size():
				out.blit_rect(grid_imgs[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
			out.save_png("res://" + arg)
			grid_imgs.clear()
			print("GRID ", arg)
		"press":
			Input.action_press(arg)
		"release":
			Input.action_release(arg)
		"tp":
			var v := arg.split_floats(",")
			var p := _player()
			p.global_position = Vector3(v[0], v[1], v[2])
			p.velocity = Vector3.ZERO
			p.spawn_position = p.global_position
			p.get_node("%Gimbal").global_position = p.global_position
		"cam":
			var v := arg.split_floats(",")
			var g: Node3D = _player().get_node("%Gimbal")
			g.rotation_degrees = Vector3(v[1], v[0], 0)
		"hide":
			get_tree().current_scene.get_node(arg).visible = false
		"list":
			for c in get_tree().current_scene.get_node(arg).get_children():
				print(c.name, " ", c.get("position"))
		"probe":
			# which visual instances cover the ground point under screen pixel x,y?
			var v := arg.split_floats(",")
			var cam := get_viewport().get_camera_3d()
			var o := cam.project_ray_origin(Vector2(v[0], v[1]))
			var dir := cam.project_ray_normal(Vector2(v[0], v[1]))
			var hit: Vector3 = Plane(Vector3.UP, 0).intersects_ray(o, dir)
			print("ground point ", hit)
			for n in get_tree().current_scene.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = n
				var ab: AABB = gi.global_transform * gi.get_aabb()
				if ab.grow(0.05).has_point(hit):
					print("  ", get_tree().current_scene.get_path_to(gi), " ", ab)
		"collect":
			for n in get_tree().current_scene.find_children("*", "Area3D", true, false):
				if n.has_method("_on_range_body_entered") and not n.collected:
					n._on_body_entered(_player())
		"scene":
			print("CURRENT SCENE ", get_tree().current_scene.name)
		"print":
			var p := _player()
			print("T=%.2f pos=%s vel=%s floor=%s anim=%s score=%d/%d lives=%d" % [t, p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p.is_on_floor(), p.animation.current_animation, GameManager.score, GameManager.total, GameManager.lives])
		"quit":
			get_tree().quit()
