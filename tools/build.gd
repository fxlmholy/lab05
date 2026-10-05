extends Node

# One-shot scaffolding script that generates the game's scenes as normal .tscn files.
# Run:  godot --headless --path . res://tools/build.tscn
# After the first build, the scenes can be edited by hand in the Godot editor.
# Re-running this script OVERWRITES them.

const CHAR_GLB := "res://Assets/Models/Characters/player_character.glb"
const ENV := "res://Assets/Models/Env/"
const CHAR_SCALE := 0.7
const PIVOT_H := 0.8

var BlockScript: Script = load("res://Scripts/Block.gd")
var MoverScript: Script = load("res://Scripts/Mover.gd")
var HazardScript: Script = load("res://Scripts/Hazard.gd")

var sroot: Node  # owner of the scene currently being built

# ---------------------------------------------------------------- helpers

func add(parent: Node, node: Node, node_name := "") -> Node:
	if node_name != "":
		node.name = node_name
	parent.add_child(node, true)
	node.owner = sroot
	return node

func n3d(parent: Node, node_name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	return add(parent, n, node_name)

func inst(parent: Node, path: String, pos := Vector3.ZERO, rot_y := 0.0, s := 1.0, node_name := "") -> Node3D:
	if not path.begins_with("res://"):
		path = ENV + path + ".glb"
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * s
	if node_name == "":
		node_name = path.get_file().get_basename().to_pascal_case()
	return add(parent, n, node_name)

func save(scene_root: Node, path: String):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var ps := PackedScene.new()
	var err := ps.pack(scene_root)
	assert(err == OK)
	err = ResourceSaver.save(ps, path)
	print("saved ", path, " -> ", err)
	scene_root.free()

func mat(c: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if emission > 0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m

func area_shape(parent: Node, shape: Shape3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	cs.rotation_degrees = rot
	return add(parent, cs, "CollisionShape3D")

func box(sz: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new(); b.size = sz; return b

func sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new(); s.radius = r; return s

func cylinder(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new(); c.radius = r; c.height = h; return c

func hazard(parent: Node, shape: Shape3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	a.set_script(HazardScript)
	add(parent, a, "Hazard")
	area_shape(a, shape, pos, rot)
	return a

func mover(parent: Node, props: Dictionary) -> Node:
	var m := Node.new()
	m.set_script(MoverScript)
	for k in props:
		m.set(k, props[k])
	return add(parent, m, "Mover")

# ---------------------------------------------------------------- icons

func make_icons():
	var star := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var pts := PackedVector2Array()
	for i in 10:
		var r := 30.0 if i % 2 == 0 else 13.0
		var a := -PI / 2 + i * PI / 5
		pts.append(Vector2(32, 34) + Vector2(cos(a), sin(a)) * r)
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, pts):
				star.set_pixel(x, y, Color(1, 0.85, 0.2))
			elif _dist_to_poly(p, pts) < 2.5:
				star.set_pixel(x, y, Color(0.35, 0.2, 0.05))
	star.save_png("res://Assets/Textures/star_icon.png")

	var heart := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var u := (x - 32) / 26.0
			var v := (30 - y) / 26.0
			var f := pow(u * u + v * v - 1, 3) - u * u * v * v * v
			if f <= 0:
				heart.set_pixel(x, y, Color(0.92, 0.2, 0.25))
			elif f < 0.12:
				heart.set_pixel(x, y, Color(0.35, 0.05, 0.08))
	heart.save_png("res://Assets/Textures/heart_icon.png")

func _dist_to_poly(p: Vector2, pts: PackedVector2Array) -> float:
	var d := INF
	for i in pts.size():
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])
		d = min(d, p.distance_to(c))
	return d

# ---------------------------------------------------------------- input map

func add_key_action(action: String, keys: Array):
	var events := []
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		events.append(e)
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.5, "events": events})

func setup_project():
	add_key_action("camera_left", [KEY_LEFT])
	add_key_action("camera_right", [KEY_RIGHT])
	add_key_action("camera_up", [KEY_UP])
	add_key_action("camera_down", [KEY_DOWN])
	add_key_action("pause", [KEY_P, KEY_ESCAPE])
	ProjectSettings.set_setting("application/run/main_scene", "res://Scenes/UI/MainMenu.tscn")
	ProjectSettings.set_setting("display/window/size/viewport_width", 1280)
	ProjectSettings.set_setting("display/window/size/viewport_height", 720)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.save()

# ---------------------------------------------------------------- character

func build_animation_library() -> AnimationLibrary:
	var glb: Node = load(CHAR_GLB).instantiate()
	var ap: AnimationPlayer = glb.find_child("AnimationPlayer", true, false)
	# Map the starter kit's animation names to the new character's clips
	var map := {
		"Idle": "Idle", "Run": "Run", "Jump": "Jump", "Flip": "Jump",
		"Fall": "Jump_Idle", "Land": "Jump_Land", "Hurt": "HitReact",
		"Death": "Death", "Victory": "Wave",
	}
	var looping := ["Idle", "Run", "Fall", "Victory"]
	var lib := AnimationLibrary.new()
	for kit_name in map:
		var a: Animation = ap.get_animation("CharacterArmature|" + map[kit_name]).duplicate(true)
		for i in a.get_track_count():
			a.track_set_path(i, NodePath("FlipPivot/Character/" + str(a.track_get_path(i))))
		a.loop_mode = Animation.LOOP_LINEAR if kit_name in looping else Animation.LOOP_NONE
		if kit_name == "Flip":
			# Front flip: spin the pivot one full turn while the jump pose plays
			a.length = 0.6
			var t := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t, "FlipPivot:rotation")
			a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
			for k in 5:
				a.track_insert_key(t, 0.6 * k / 4.0, Vector3(TAU * k / 4.0, 0, 0))
		lib.add_animation(kit_name, a)
	glb.free()
	ResourceSaver.save(lib, "res://Assets/Models/Characters/player_animations.tres")
	return load("res://Assets/Models/Characters/player_animations.tres")

func build_character_model(lib: AnimationLibrary):
	sroot = Node3D.new()
	sroot.name = "CharacterModel"
	var pivot := n3d(sroot, "FlipPivot", Vector3(0, PIVOT_H, 0))
	inst(pivot, CHAR_GLB, Vector3(0, -PIVOT_H, 0), 0, CHAR_SCALE, "Character")
	var ap := AnimationPlayer.new()
	ap.root_node = NodePath("..")
	ap.add_animation_library("", lib)
	ap.autoplay = "Idle"
	add(sroot, ap, "AnimationPlayer")
	save(sroot, "res://Scenes/Characters/CharacterModel.tscn")

func build_player():
	var old: Node = load("res://Scenes/player.tscn").instantiate()
	sroot = CharacterBody3D.new()
	sroot.name = "Player"
	sroot.add_to_group("Player", true)
	sroot.set_script(load("res://Scripts/player.gd"))
	sroot.floor_snap_length = 0.3

	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	area_shape(sroot, cap, Vector3(0, 0.75, 0))
	inst(sroot, "res://Scenes/Characters/CharacterModel.tscn", Vector3.ZERO, 0, 1.0, "Model")

	# Re-use the kit's camera rig, trail particles and footstep sound
	for keep in ["Gimbal", "ParticleTrail", "Footsteps"]:
		var n: Node = old.get_node(keep).duplicate()
		add(sroot, n, keep)
		for c in n.get_children():
			c.owner = sroot
	var gimbal: Node3D = sroot.get_node("Gimbal")
	gimbal.unique_name_in_owner = true
	gimbal.rotation_degrees.x = -12
	var cam: Camera3D = gimbal.get_node("Camera3D")
	cam.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-8)), Vector3(0, 1.6, 6.5))
	cam.fov = 70
	cam.far = 400
	old.free()
	save(sroot, "res://Scenes/player.tscn")

# ---------------------------------------------------------------- props

func build_props():
	# Star collectible
	# Sparkles originally came from the kit's Coin.tscn; reuse the existing Star once that is gone
	var coin_path := "res://Scenes/Coin.tscn" if FileAccess.file_exists("res://Scenes/Coin.tscn") else "res://Scenes/Props/Star.tscn"
	var coin: Node = load(coin_path).instantiate()
	sroot = Area3D.new(); sroot.name = "Star"
	sroot.set_script(load("res://Scripts/Collectible.gd"))
	inst(sroot, "star", Vector3(0, -0.45, 0), 0, 0.75, "Model")
	area_shape(sroot, sphere(0.6))
	var sparkles: Node = coin.get_node("Sparkles").duplicate()
	add(sroot, sparkles, "Sparkles")
	var rng := Area3D.new()
	add(sroot, rng, "Range")
	area_shape(rng, sphere(1.6))
	coin.free()
	save(sroot, "res://Scenes/Props/Star.tscn")

	# Saw blade (spins; levels add a Mover to slide it around)
	sroot = Node3D.new(); sroot.name = "SawBlade"
	var blade := n3d(sroot, "Blade")
	inst(blade, "saw_blade", Vector3.ZERO, 0, 0.6, "Model")
	mover(blade, {"mode": 1, "axis": Vector3(0, 0, 1), "speed_deg": -540.0})
	hazard(sroot, cylinder(0.8, 0.4), Vector3.ZERO, Vector3(90, 0, 0))
	var slot := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.25, 0.08, 0.25); sm.material = mat(Color(0.15, 0.15, 0.17))
	slot.mesh = sm
	add(sroot, slot, "Hub")
	save(sroot, "res://Scenes/Props/SawBlade.tscn")

	# Spiky ball swinging around a post
	sroot = Node3D.new(); sroot.name = "SpikyBallOrbit"
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.2; pm.bottom_radius = 0.3; pm.height = 1.4; pm.radial_segments = 6
	pm.material = mat(Color(0.25, 0.23, 0.28))
	post.mesh = pm; post.position.y = 0.7
	add(sroot, post, "Post")
	var arm := n3d(sroot, "Arm", Vector3(0, 1.0, 0))
	mover(arm, {"mode": 1, "axis": Vector3.UP, "speed_deg": 100.0})
	var chain := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(3.0, 0.1, 0.1); cm.material = mat(Color(0.35, 0.33, 0.38))
	chain.mesh = cm; chain.position.x = 1.5
	add(arm, chain, "Chain")
	inst(arm, "spiky_ball", Vector3(3, 0, 0), 0, 1.0, "Ball")
	hazard(arm, sphere(0.6), Vector3(3, 0, 0))
	save(sroot, "res://Scenes/Props/SpikyBallOrbit.tscn")

	# Spike trap
	sroot = Node3D.new(); sroot.name = "SpikeTrap"
	sroot.set_script(load("res://Scripts/SpikeTrap.gd"))
	inst(sroot, "spike_trap", Vector3(0, 0.02, 0), 0, 1.0, "Model")
	hazard(sroot, box(Vector3(1.7, 0.9, 1.7)), Vector3(0, 0.45, 0))
	save(sroot, "res://Scenes/Props/SpikeTrap.tscn")

	# Static spikes
	sroot = Node3D.new(); sroot.name = "Spikes"
	inst(sroot, "spikes", Vector3.ZERO, 0, 0.45, "Model")
	hazard(sroot, box(Vector3(0.8, 1.4, 0.8)), Vector3(0, 0.7, 0))
	save(sroot, "res://Scenes/Props/Spikes.tscn")

	# Wooden stakes (forest version of static spikes)
	sroot = Node3D.new(); sroot.name = "WoodenStakes"
	var offsets := [Vector3(-0.4, 0, -0.2), Vector3(0.1, 0, 0.3), Vector3(0.45, 0, -0.3), Vector3(-0.2, 0, 0.45), Vector3(0.05, 0, -0.55)]
	for i in offsets.size():
		var st := inst(sroot, "wooden_spike", offsets[i], i * 40.0, 0.8 + (i % 3) * 0.12, "Stake%d" % i)
		st.rotation_degrees.x = (i % 2) * 8.0 - 4.0
	hazard(sroot, box(Vector3(1.4, 1.2, 1.4)), Vector3(0, 0.6, 0))
	save(sroot, "res://Scenes/Props/WoodenStakes.tscn")

	# Spinning spiked pillar
	sroot = Node3D.new(); sroot.name = "SpikedPillar"
	var pil := inst(sroot, "cylinder_hazard", Vector3.ZERO, 0, 0.6, "Model")
	mover(pil, {"mode": 1, "axis": Vector3.UP, "speed_deg": 150.0})
	hazard(sroot, cylinder(0.75, 2.3), Vector3(0, 1.15, 0))
	save(sroot, "res://Scenes/Props/SpikedPillar.tscn")

	# Spring pad
	sroot = Node3D.new(); sroot.name = "Spring"
	inst(sroot, "spring", Vector3.ZERO, 0, 0.55, "Model")
	var pad := Area3D.new()
	pad.set_script(load("res://Scripts/Spring.gd"))
	add(sroot, pad, "Pad")
	area_shape(pad, box(Vector3(1.1, 0.6, 1.1)), Vector3(0, 0.8, 0))
	save(sroot, "res://Scenes/Props/Spring.tscn")

	# Checkpoint flag
	sroot = Area3D.new(); sroot.name = "Checkpoint"
	sroot.set_script(load("res://Scripts/Checkpoint.gd"))
	inst(sroot, "goal_flag", Vector3.ZERO, 0, 1.0, "Flag")
	area_shape(sroot, box(Vector3(2.5, 3, 2.5)), Vector3(0, 1.5, 0))
	var sp := Marker3D.new(); sp.position = Vector3(0, 0.2, 1.2)
	add(sroot, sp, "SpawnPoint")
	save(sroot, "res://Scenes/Props/Checkpoint.tscn")

	# Exit door
	sroot = Node3D.new(); sroot.name = "Door"
	sroot.set_script(load("res://Scripts/Door.gd"))
	inst(sroot, "arch", Vector3.ZERO, 0, 1.0, "Arch")
	var hinge := n3d(sroot, "Hinge", Vector3(-1.21, 0, 0))
	inst(hinge, "arch_door", Vector3(1.21, 0, 0), 0, 1.0, "DoorModel")
	var glow := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(2.3, 3.1)
	var gm := mat(Color(1.0, 0.8, 0.35), 2.0)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = gm
	glow.mesh = qm; glow.position = Vector3(0, 1.55, -0.2)
	add(sroot, glow, "Portal")
	var walls := StaticBody3D.new()
	add(sroot, walls, "Frame")
	area_shape(walls, box(Vector3(0.85, 4, 1)), Vector3(-1.62, 2, 0))
	area_shape(walls, box(Vector3(0.85, 4, 1)), Vector3(1.62, 2, 0))
	area_shape(walls, box(Vector3(4.1, 0.8, 1)), Vector3(0, 3.6, 0))
	var blocker := StaticBody3D.new()
	add(sroot, blocker, "Blocker")
	area_shape(blocker, box(Vector3(2.4, 3.2, 0.4)), Vector3(0, 1.6, 0))
	var exit := Area3D.new()
	add(sroot, exit, "ExitArea")
	area_shape(exit, box(Vector3(2.2, 3, 1.2)), Vector3(0, 1.5, -0.6))
	var lbl := Label3D.new()
	lbl.position = Vector3(0, 4.7, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 72
	lbl.outline_size = 18
	lbl.pixel_size = 0.008
	lbl.text = "LOCKED"
	add(sroot, lbl, "Label3D")
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.8, 0.8)
	light.light_color = Color(1, 0.8, 0.4)
	light.light_energy = 2.0
	light.omni_range = 6.0
	add(sroot, light, "Light")
	save(sroot, "res://Scenes/Props/Door.tscn")

	# Wall torch with flame + light
	sroot = Node3D.new(); sroot.name = "Torch"
	inst(sroot, "torch", Vector3.ZERO, 0, 1.2, "Model")
	var fire := CPUParticles3D.new()
	fire.position = Vector3(0, 0.75, 0.05)
	fire.amount = 16
	fire.lifetime = 0.5
	var fm := SphereMesh.new(); fm.radius = 0.07; fm.height = 0.14; fm.radial_segments = 6; fm.rings = 3
	var fmat := mat(Color(1, 0.55, 0.1), 3.0)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.vertex_color_use_as_albedo = true
	fm.material = fmat
	fire.mesh = fm
	fire.direction = Vector3.UP
	fire.spread = 15
	fire.gravity = Vector3(0, 2, 0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.7
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.3
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0))
	fire.scale_amount_curve = curve
	var grad := Gradient.new(); grad.set_color(0, Color(1, 0.9, 0.3)); grad.set_color(1, Color(0.9, 0.2, 0.05))
	fire.color_ramp = grad
	add(sroot, fire, "Fire")
	var tl := OmniLight3D.new()
	tl.position = Vector3(0, 0.9, 0.4)
	tl.light_color = Color(1, 0.6, 0.25)
	tl.light_energy = 1.6
	tl.omni_range = 7.0
	add(sroot, tl, "Light")
	save(sroot, "res://Scenes/Props/Torch.tscn")

# ---------------------------------------------------------------- UI

func label(parent: Node, text: String, size: int, node_name: String, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = max(size / 6, 4)
	ls.outline_color = Color(0.08, 0.06, 0.12)
	ls.shadow_size = 0
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return add(parent, l, node_name)

func button(parent: Node, text: String, node_name: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 28)
	return add(parent, b, node_name)

func build_game_ui():
	sroot = Control.new(); sroot.name = "GameUI"
	sroot.set_script(load("res://Scripts/GameUI.gd"))
	sroot.set_anchors_preset(Control.PRESET_FULL_RECT)
	sroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sroot.process_mode = Node.PROCESS_MODE_ALWAYS

	var bar := HBoxContainer.new()
	add(sroot, bar, "TopBar")
	bar.position = Vector2(24, 18)
	bar.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = load("res://Assets/Textures/star_icon.png")
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add(bar, icon, "StarIcon")
	label(bar, "x 0 / 0", 36, "CoinsLabel", Color(1, 0.86, 0.3))
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(40, 0)
	add(bar, spacer, "Spacer")
	var hicon := TextureRect.new()
	hicon.texture = load("res://Assets/Textures/heart_icon.png")
	hicon.custom_minimum_size = Vector2(44, 44)
	hicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add(bar, hicon, "HeartIcon")
	label(bar, "x 5", 36, "LivesLabel", Color(1, 0.55, 0.55))

	var title := label(sroot, "", 64, "LevelTitle", Color(1, 0.95, 0.8))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-500, 120)
	title.size = Vector2(1000, 180)

	var msg := label(sroot, "", 34, "Message")
	msg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	msg.position = Vector2(-500, -150)
	msg.size = Vector2(1000, 60)

	var help := label(sroot, "WASD move  |  SPACE jump (x2 = flip)  |  Mouse / Arrows camera  |  ESC pause", 18, "Help", Color(1, 1, 1, 0.8))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -40)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var panel := PanelContainer.new()
	add(sroot, panel, "PausePanel")
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180, -170)
	panel.custom_minimum_size = Vector2(360, 340)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	add(panel, vb, "VBox")
	label(vb, "PAUSED", 48, "Title")
	button(vb, "Resume", "Resume")
	button(vb, "Restart Level", "Restart")
	button(vb, "Main Menu", "Menu")
	save(sroot, "res://Scenes/UI/GameUI.tscn")

# ---------------------------------------------------------------- environments

func make_environment(parent: Node, forest: bool):
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if forest:
		sm.sky_top_color = Color(0.32, 0.58, 0.92)
		sm.sky_horizon_color = Color(0.75, 0.88, 0.95)
		sm.ground_horizon_color = Color(0.75, 0.88, 0.95)
		sm.ground_bottom_color = Color(0.45, 0.65, 0.8)
	else:
		sm.sky_top_color = Color(0.16, 0.1, 0.28)
		sm.sky_horizon_color = Color(0.9, 0.42, 0.25)
		sm.ground_horizon_color = Color(0.9, 0.42, 0.25)
		sm.ground_bottom_color = Color(0.35, 0.08, 0.05)
		sm.sun_angle_max = 20
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45 if forest else 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.3 if forest else 0.8
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.75, 0.86, 0.95) if forest else Color(0.55, 0.22, 0.18)
	env.fog_depth_begin = 60.0 if forest else 35.0
	env.fog_depth_end = 220.0 if forest else 150.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	we.environment = env
	add(parent, we, "WorldEnvironment")

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0) if forest else Vector3(-35, -140, 0)
	sun.light_color = Color(1, 0.96, 0.88) if forest else Color(1, 0.62, 0.45)
	sun.light_energy = 1.0 if forest else 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	add(parent, sun, "Sun")

# ---------------------------------------------------------------- level helpers

func block(parent: Node, pos: Vector3, sz: Vector3, style := 0, island := true, deco := true) -> AnimatableBody3D:
	var b := AnimatableBody3D.new()
	b.set_script(BlockScript)
	b.position = pos
	b.size = sz
	b.style = style
	b.island_bottom = island
	b.decorate = deco
	return add(parent, b, "Block")

func star(parent: Node, pos: Vector3):
	inst(parent, "res://Scenes/Props/Star.tscn", pos, 0, 1.0, "Star")

func level_base(index: int, title: String, subtitle: String, forest: bool) -> Dictionary:
	sroot = Node3D.new()
	sroot.name = "Level%d" % (index + 1)
	sroot.set_script(load("res://Scripts/Level.gd"))
	sroot.set("level_index", index)
	sroot.set("title", title)
	sroot.set("subtitle", subtitle)
	make_environment(sroot, forest)
	inst(sroot, "res://Scenes/player.tscn", Vector3(0, 0.2, 2), 0, 1.0, "Player")
	var ui := CanvasLayer.new()
	add(sroot, ui, "UserInterface")
	add(ui, load("res://Scenes/UI/GameUI.tscn").instantiate(), "GameUI")
	var dz := Area3D.new()
	dz.set_script(load("res://Scripts/DeadZone.gd"))
	dz.position = Vector3(0, -14, -50)
	add(sroot, dz, "DeadZone")
	area_shape(dz, box(Vector3(400, 4, 400)))
	return {
		"ground": n3d(sroot, "Ground"),
		"items": n3d(sroot, "Stars"),
		"hazards": n3d(sroot, "Hazards"),
		"deco": n3d(sroot, "Decoration"),
		"gameplay": n3d(sroot, "Gameplay"),
	}

func signpost(parent: Node, pos: Vector3, rot_y: float, text: String):
	var s := inst(parent, "wooden_sign", pos, rot_y, 1.3, "Sign")
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.outline_size = 10
	l.pixel_size = 0.004
	l.position = Vector3(0, 2.4, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add(s, l, "Text")

# ---------------------------------------------------------------- LEVEL 1: forest

func build_level1():
	var L := level_base(0, "LEVEL 1", "Whispering Forest", true)
	var g: Node3D = L.ground; var it: Node3D = L.items; var hz: Node3D = L.hazards; var d: Node3D = L.deco; var gp: Node3D = L.gameplay

	# --- Start island
	block(g, Vector3(0, 0, 0), Vector3(12, 2, 12))
	signpost(d, Vector3(-2.5, 0, -2), 20, "Collect every star\nto open the door!")
	inst(d, "tree_large", Vector3(-4.5, 0, 4), 0, 1.0)
	inst(d, "tree", Vector3(4.2, 0, 3.5), 60, 0.8)
	inst(d, "pine", Vector3(-4.6, 0, -3.8), 0, 0.7)
	inst(d, "bush_flowers", Vector3(3.8, 0, -4), 30, 0.8)
	inst(d, "flower_group", Vector3(1.5, 0, 4.6), 0, 0.8)
	inst(d, "mushroom", Vector3(-3, 0, 1), 0, 1.5)
	inst(d, "mushroom", Vector3(-2.6, 0, 1.6), 70, 1.0)
	inst(d, "rock_small", Vector3(5, 0, 0), 0, 0.5)
	inst(d, "wooden_fence", Vector3(-1.5, 0, 5.4), 0, 1.0)
	inst(d, "wooden_fence", Vector3(1.6, 0, 5.4), 0, 1.0)

	# --- Stepping islands
	block(g, Vector3(0, 0.5, -10), Vector3(4, 1.5, 4))
	star(it, Vector3(0, 1.6, -10))
	block(g, Vector3(3, 1.2, -16), Vector3(4, 1.5, 4))
	star(it, Vector3(3, 2.3, -16))
	inst(d, "tree_small", Vector3(4.3, 1.2, -17.2), 0, 0.8)

	# --- Moving log raft
	var raft := block(g, Vector3(3, 1.2, -21.5), Vector3(3, 0.4, 3), 2, false)
	raft.name = "MovingRaft"
	mover(raft, {"mode": 0, "offset": Vector3(0, 0, -6), "duration": 5.0})
	star(it, Vector3(3, 2.6, -24.5))

	# --- Big meadow with spike traps
	block(g, Vector3(3, 1.2, -38), Vector3(14, 2.5, 14))
	inst(gp, "res://Scenes/Props/Checkpoint.tscn", Vector3(0, 1.2, -32.8), 0, 1.0, "Checkpoint")
	var traps := [Vector3(0, 1.2, -37), Vector3(3, 1.2, -39), Vector3(6, 1.2, -37), Vector3(3, 1.2, -35), Vector3(0, 1.2, -41), Vector3(6, 1.2, -41)]
	for i in traps.size():
		var t := inst(hz, "res://Scenes/Props/SpikeTrap.tscn", traps[i], 0, 1.0, "SpikeTrap")
		t.set("phase", fmod(i * 0.37, 1.0))
	star(it, Vector3(3, 2.3, -37))
	star(it, Vector3(8.5, 2.3, -43.5))
	for p in [Vector3(-3, 1.2, -44), Vector3(9, 1.2, -32), Vector3(-3, 1.2, -32.5)]:
		inst(hz, "res://Scenes/Props/WoodenStakes.tscn", p, 0, 1.0, "WoodenStakes")
	inst(d, "tree_large", Vector3(-2.8, 1.2, -38), 0, 1.1)
	inst(d, "pine", Vector3(9, 1.2, -38), 0, 0.6)
	inst(d, "bush_flowers", Vector3(8.5, 1.2, -34.5), 0, 0.7)
	inst(d, "rock_large", Vector3(-2.5, 1.2, -35), 20, 0.8)
	inst(d, "fern", Vector3(7.5, 1.2, -40.5), 0, 0.12)

	# --- Secret side island
	block(g, Vector3(14, 2.4, -38), Vector3(4, 1.5, 4))
	star(it, Vector3(14, 3.5, -38))
	inst(d, "tree", Vector3(15, 2.4, -39.2), 0, 0.6)

	# --- Saw blade bridge
	block(g, Vector3(3, 1.2, -52), Vector3(3, 0.6, 14), 2, false)
	for i in 2:
		var saw := inst(hz, "res://Scenes/Props/SawBlade.tscn", Vector3(0.2, 1.4, -49 - i * 6), 0, 1.0, "SawBlade")
		mover(saw, {"mode": 0, "offset": Vector3(5.6, 0, 0), "duration": 2.8, "phase": i * 0.5})
	star(it, Vector3(3, 2.0, -52))
	star(it, Vector3(3, 2.0, -57.5))

	# --- Spring up to the high island
	block(g, Vector3(3, 1.2, -62), Vector3(5, 1.5, 5))
	inst(gp, "res://Scenes/Props/Spring.tscn", Vector3(3, 1.2, -63.2), 0, 1.0, "Spring")
	signpost(d, Vector3(0.9, 1.2, -60.5), 30, "Jump on the\nspring!")

	block(g, Vector3(3, 7, -71), Vector3(8, 2, 8))
	inst(hz, "res://Scenes/Props/SpikyBallOrbit.tscn", Vector3(3, 7, -71), 0, 1.0, "SpikyBallOrbit")
	star(it, Vector3(6, 8, -74))
	inst(d, "pine", Vector3(0, 7, -74), 0, 0.55)
	inst(d, "flower_group", Vector3(6, 7, -68), 0, 0.7)
	inst(gp, "res://Scenes/Props/Checkpoint.tscn", Vector3(0.5, 7, -68), 0, 1.0, "Checkpoint2")

	# --- Floating stepping stones
	block(g, Vector3(3, 6.5, -79), Vector3(3, 1, 3))
	block(g, Vector3(-1, 6.2, -83.5), Vector3(3, 1, 3))
	star(it, Vector3(-1, 7.3, -83.5))

	# --- Final island with the door
	block(g, Vector3(-1, 6, -93), Vector3(12, 2.5, 12))
	inst(gp, "res://Scenes/Props/Door.tscn", Vector3(-1, 6, -97.5), 0, 1.0, "Door")
	star(it, Vector3(-5, 7.1, -91))
	star(it, Vector3(3, 7.1, -91))
	inst(hz, "res://Scenes/Props/WoodenStakes.tscn", Vector3(-5, 6, -89.3), 0, 1.0, "WoodenStakes")
	inst(hz, "res://Scenes/Props/WoodenStakes.tscn", Vector3(-3.3, 6, -91), 0, 1.0, "WoodenStakes")
	var saw3 := inst(hz, "res://Scenes/Props/SawBlade.tscn", Vector3(3, 6.2, -88.5), 90, 1.0, "SawBlade")
	mover(saw3, {"mode": 0, "offset": Vector3(0, 0, -5), "duration": 3.0})
	inst(d, "tree_large", Vector3(-5.5, 6, -97), 0, 1.2)
	inst(d, "tree_large", Vector3(3.5, 6, -97), 0, 1.2)
	inst(d, "bush_flowers", Vector3(-6, 6, -94), 0, 0.8)
	inst(d, "bush_flowers", Vector3(4, 6, -94), 0, 0.8)
	inst(d, "rock_small", Vector3(4.2, 6, -88), 0, 0.4)

	# --- Background scenery
	var far := n3d(d, "Background")
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 14:
		var side := -1 if i % 2 == 0 else 1
		var p := Vector3(side * rng.randf_range(25, 55), rng.randf_range(-6, 14), rng.randf_range(10, -120))
		var isl := inst(far, "floating_island" if i % 3 else "floating_island2", p, rng.randf() * 360, rng.randf_range(2.5, 5.0), "Island")
		if i % 2 == 0:
			inst(far, "pine", p + Vector3(0, 0.6 * isl.scale.y, 0), 0, isl.scale.y * 0.25, "IslandTree")
	for i in 16:
		var side := -1 if i % 2 == 0 else 1
		var p := Vector3(side * rng.randf_range(16, 60), rng.randf_range(-26, -16), rng.randf_range(20, -130))
		inst(far, "cloud", p, rng.randf() * 360, rng.randf_range(2, 4), "Cloud")

	save(sroot, "res://Scenes/Levels/Level1.tscn")

# ---------------------------------------------------------------- LEVEL 2: castle

func build_level2():
	var L := level_base(1, "LEVEL 2", "The Lava Keep", false)
	var g: Node3D = L.ground; var it: Node3D = L.items; var hz: Node3D = L.hazards; var d: Node3D = L.deco; var gp: Node3D = L.gameplay

	# Lava sea
	var lava := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(400, 400)
	var sh := ShaderMaterial.new(); sh.shader = load("res://Assets/Shaders/lava.gdshader")
	pm.material = sh
	lava.mesh = pm
	lava.position = Vector3(0, -5, -50)
	add(d, lava, "Lava")

	const S := 1 # Block.Style.STONE
	# --- Entrance
	block(g, Vector3(0, 0, 0), Vector3(12, 2, 12), S)
	for x in [-5, 5]:
		inst(d, "column", Vector3(x, 0, 5), 0, 1.0)
		inst(d, "column", Vector3(x, 0, -5), 0, 1.0)
	inst(d, "banner", Vector3(-5.6, 0, -2), 90, 1.0)
	inst(d, "banner", Vector3(5.6, 0, -2), -90, 1.0)
	inst(d, "barrel", Vector3(-4.5, 0, 1), 0, 1.0)
	inst(d, "barrel", Vector3(-4.3, 0, 2.3), 40, 0.9)
	inst(d, "crate", Vector3(4.5, 0, 1.5), 15, 1.0)
	inst(d, "skull", Vector3(3, 0, -3), 200, 1.0)
	inst(d, "res://Scenes/Props/Torch.tscn", Vector3(-5, 2.5, 4.3), 180, 1.0, "Torch")
	inst(d, "res://Scenes/Props/Torch.tscn", Vector3(5, 2.5, 4.3), 180, 1.0, "Torch")
	signpost(d, Vector3(2.5, 0, -3.8), -20, "Mind the spikes\nand the lava!")

	# --- Spike trap corridor
	block(g, Vector3(0, 0, -14), Vector3(2, 2, 16), S)
	for i in 4:
		var t := inst(hz, "res://Scenes/Props/SpikeTrap.tscn", Vector3(0, 0, -8 - i * 3.6), 0, 1.0, "SpikeTrap")
		t.set("phase", i * 0.25)
		t.set("interval", 2.0)
	star(it, Vector3(0, 1.1, -11.6))
	star(it, Vector3(0, 1.1, -18.8))

	# --- Moving stone platform over the lava
	var plat := block(g, Vector3(-2.5, 0.5, -27), Vector3(4, 1, 4), S, true, false)
	plat.name = "MovingPlatform"
	mover(plat, {"mode": 0, "offset": Vector3(5, 0, 0), "duration": 4.0})
	star(it, Vector3(0, 2.2, -27))

	# --- Great hall with spiked ball
	block(g, Vector3(0, 1, -40), Vector3(14, 2.5, 16), S)
	inst(gp, "res://Scenes/Props/Checkpoint.tscn", Vector3(-4, 1, -33.5), 0, 1.0, "Checkpoint")
	inst(hz, "res://Scenes/Props/SpikyBallOrbit.tscn", Vector3(0, 1, -40), 0, 1.0, "SpikyBallOrbit")
	var big := inst(hz, "res://Scenes/Props/SpikyBallOrbit.tscn", Vector3(0, 1, -40), 0, 1.0, "SpikyBallOrbitBig")
	big.get_node("Arm/Mover").set("speed_deg", -60.0)
	big.get_node("Arm/Ball").position.x = 5.5
	big.get_node("Arm/Hazard/CollisionShape3D").position.x = 5.5
	big.get_node("Arm/Chain").position.x = 2.75
	big.get_node("Arm/Chain").scale.x = 5.5 / 3.0
	star(it, Vector3(0, 2.1, -41.6))
	star(it, Vector3(-5.5, 2.1, -46.5))
	star(it, Vector3(5.5, 2.1, -34))
	for p in [Vector3(-6.3, 1, -32.7), Vector3(6.3, 1, -32.7), Vector3(-6.3, 1, -47.3), Vector3(6.3, 1, -47.3)]:
		inst(d, "column2", p, 0, 1.0)
	inst(d, "res://Scenes/Props/Torch.tscn", Vector3(-6.3, 3.4, -46.6), 0, 1.0, "Torch")
	inst(d, "res://Scenes/Props/Torch.tscn", Vector3(6.3, 3.4, -46.6), 0, 1.0, "Torch")
	inst(d, "banner_wall", Vector3(-3, 4.6, -47.6), 0, 1.0)
	inst(d, "banner_wall", Vector3(3, 4.6, -47.6), 0, 1.0)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		if abs(x) > 1.5:
			inst(d, "wall", Vector3(x, 2, -47.8), 0, 1.0)
	inst(d, "cobweb", Vector3(-6.1, 4.2, -47.2), 0, 1.2)
	inst(d, "barrel", Vector3(6, 1, -36), 0, 0.9)
	inst(d, "crate", Vector3(-6, 1, -40), 30, 0.9)
	inst(d, "skull", Vector3(4, 1, -44), 120, 1.0)

	# --- Stairs over lava, guarded by a saw
	block(g, Vector3(0, 2, -52), Vector3(4, 1.5, 4), S)
	star(it, Vector3(0, 3.1, -52))
	block(g, Vector3(3, 3, -58), Vector3(4, 1.5, 4), S)
	var saw := inst(hz, "res://Scenes/Props/SawBlade.tscn", Vector3(1.2, 3.2, -58), 0, 1.0, "SawBlade")
	mover(saw, {"mode": 0, "offset": Vector3(3.6, 0, 0), "duration": 2.0})
	block(g, Vector3(0, 4, -64), Vector3(4, 1.5, 4), S)
	star(it, Vector3(0, 5.1, -64))

	# --- Bridge with spinning pillars
	block(g, Vector3(0, 4, -74), Vector3(4, 0.6, 16), 2, false)
	for i in 2:
		var pil := inst(hz, "res://Scenes/Props/SpikedPillar.tscn", Vector3(-1.5, 4, -70 - i * 7), 0, 1.0, "SpikedPillar")
		mover(pil, {"mode": 0, "offset": Vector3(3, 0, 0), "duration": 2.4, "phase": i * 0.5})
	star(it, Vector3(0, 5, -73.5))

	# --- Throne room with the exit
	block(g, Vector3(0, 4, -90), Vector3(14, 2.5, 16), S)
	inst(gp, "res://Scenes/Props/Checkpoint.tscn", Vector3(4, 4, -83.5), 0, 1.0, "Checkpoint2")
	inst(gp, "res://Scenes/Props/Door.tscn", Vector3(0, 4, -97.5), 0, 1.0, "Door")
	for i in 3:
		var t := inst(hz, "res://Scenes/Props/SpikeTrap.tscn", Vector3(-2 + i * 2, 4, -93), 0, 1.0, "SpikeTrap")
		t.set("phase", i * 0.33)
	star(it, Vector3(-5, 5.1, -88))
	star(it, Vector3(5, 5.1, -91))
	inst(hz, "res://Scenes/Props/Spikes.tscn", Vector3(-3.5, 4, -88), 0, 1.0, "Spikes")
	inst(hz, "res://Scenes/Props/Spikes.tscn", Vector3(-5, 4, -86.3), 0, 1.0, "Spikes")
	inst(hz, "res://Scenes/Props/Spikes.tscn", Vector3(5, 4, -89.2), 0, 1.0, "Spikes")
	for x in [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0]:
		inst(d, "wall", Vector3(x, 6, -97.8), 0, 1.0)
		inst(d, "wall", Vector3(x, 8, -97.8), 0, 1.0)
	for p in [Vector3(-6.3, 4, -82.7), Vector3(6.3, 4, -82.7)]:
		inst(d, "column", p, 0, 1.0)
	inst(d, "res://Scenes/Props/Torch.tscn", Vector3(-3, 6.8, -97.4), 0, 1.0, "Torch")
	inst(d, "res://Scenes/Props/Torch.tscn", Vector3(3, 6.8, -97.4), 0, 1.0, "Torch")
	inst(d, "banner", Vector3(-5, 4, -97.4), 0, 1.0)
	inst(d, "banner", Vector3(5, 4, -97.4), 0, 1.0)
	inst(d, "chest", Vector3(-5.5, 4, -95.5), 30, 1.0)
	inst(d, "pedestal", Vector3(5.5, 4, -95.5), 0, 0.8)
	inst(d, "sword_mount", Vector3(-1, 9.3, -97.5), 0, 1.5)
	inst(d, "barrel", Vector3(6, 4, -86), 0, 0.9)

	# --- Background towers rising from the lava
	var far := n3d(d, "Background")
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in 10:
		var side := -1 if i % 2 == 0 else 1
		var p := Vector3(side * rng.randf_range(18, 40), rng.randf_range(6, 16), -i * 12.0 + rng.randf_range(-4, 4))
		var w := rng.randf_range(4, 7)
		var tw := block(far, p, Vector3(w, p.y + 6, w), S, false, false)
		tw.name = "Tower"
		inst(far, "banner", p + Vector3(0, -4, w / 2.0 + 0.15) if side < 0 else p + Vector3(0, -4, w / 2.0 + 0.15), 0, 1.4, "TowerBanner")
		for k in 4:
			var a := k * PI / 2
			inst(far, "column", p + Vector3(cos(a), 0, sin(a)) * (w / 2.0 - 0.6), 0, 0.5, "Crenel")

	save(sroot, "res://Scenes/Levels/Level2.tscn")

# ---------------------------------------------------------------- menus

func showcase(script_path: String, scene_name: String, forest: bool) -> VBoxContainer:
	sroot = Node3D.new(); sroot.name = scene_name
	sroot.set_script(load(script_path))
	make_environment(sroot, forest)
	block(sroot, Vector3(0, 0, 0), Vector3(8, 2, 8), 0 if forest else 1)
	inst(sroot, "res://Scenes/Characters/CharacterModel.tscn", Vector3(0, 0, 0), 0, 1.0, "Character")
	inst(sroot, "tree_large", Vector3(-2.8, 0, -2.5), 0, 1.0)
	inst(sroot, "pine", Vector3(2.8, 0, -2.8), 0, 0.5)
	inst(sroot, "bush_flowers", Vector3(2.6, 0, 2.4), 0, 0.6)
	inst(sroot, "flower_group", Vector3(-2.5, 0, 2.5), 0, 0.6)
	inst(sroot, "res://Scenes/Props/Star.tscn", Vector3(-1.4, 1.6, 1.2), 0, 1.0, "Star")
	var pivot := n3d(sroot, "CameraPivot")
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.0, 6.0)
	cam.rotation_degrees.x = -10
	cam.fov = 55
	add(pivot, cam, "Camera3D")
	for i in 8:
		var a := i * TAU / 8
		inst(sroot, "cloud", Vector3(cos(a) * 22, -4 + (i % 3) * 3, sin(a) * 22), i * 45.0, 2.5, "Cloud")
	var ui := CanvasLayer.new()
	add(sroot, ui, "UI")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add(ui, center, "Center")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	add(center, vb, "VBox")
	return vb

func build_menus():
	var vb := showcase("res://Scripts/MainMenu.gd", "MainMenu", true)
	label(vb, "LAB05", 96, "Title", Color(1, 0.86, 0.3))
	label(vb, "Collect every star, dodge the traps, reach the door!", 26, "Subtitle")
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 250)
	add(vb, gap, "Gap")
	button(vb, "START", "Start")
	button(vb, "QUIT", "Quit")
	label(vb, "WASD move  |  SPACE jump, again to flip  |  Mouse / Arrows camera  |  ESC pause", 18, "Help", Color(1, 1, 1, 0.85))
	var credits := label(sroot.get_node("UI"), "Character & props: Quaternius (CC0), J-Toastie (CC-BY 3.0) via Poly Pizza  |  Base: 3D Platformer Starter Kit by SD Studios (CC0)", 14, "Credits", Color(1, 1, 1, 0.7))
	credits.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credits.position = Vector2(0, -32)
	save(sroot, "res://Scenes/UI/MainMenu.tscn")

	vb = showcase("res://Scripts/WinScreen.gd", "WinScreen", false)
	label(vb, "YOU WIN!", 96, "Title", Color(1, 0.86, 0.3))
	label(vb, "", 30, "Stats")
	var gap2 := Control.new(); gap2.custom_minimum_size = Vector2(0, 220)
	add(vb, gap2, "Gap")
	button(vb, "PLAY AGAIN", "Again")
	button(vb, "MAIN MENU", "Menu")
	save(sroot, "res://Scenes/UI/WinScreen.tscn")

# ---------------------------------------------------------------- main

func _ready():
	if not FileAccess.file_exists("res://Assets/Textures/star_icon.png.import"):
		# Icons must be imported before scenes can use them: run --import, then this script again
		make_icons()
		print("ICONS CREATED - run godot --import and build again")
		get_tree().quit()
		return
	setup_project()
	var lib := build_animation_library()
	build_character_model(lib)
	build_player()
	build_props()
	build_game_ui()
	build_level1()
	build_level2()
	build_menus()
	get_tree().quit()
