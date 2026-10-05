@tool
extends AnimatableBody3D

# Low-poly ground block used to build the levels.
# The top surface sits at the node's origin, so placing a block at y = 2
# means the player walks at height 2. Visuals and collision are generated
# from `size` and `style`, in the editor and in game.

enum Style { GRASS, STONE, WOOD }

@export var size := Vector3(4, 1, 4):
	set(v):
		size = v
		_rebuild()
@export var style: Style = Style.GRASS:
	set(v):
		style = v
		_rebuild()
## Adds a rocky spike under the block so it looks like a floating island
@export var island_bottom := true:
	set(v):
		island_bottom = v
		_rebuild()
## Scatter grass / floor tiles on top
@export var decorate := true:
	set(v):
		decorate = v
		_rebuild()

const GRASS_TUFT := preload("res://Assets/Models/Env/grass.glb")
const TALL_GRASS := preload("res://Assets/Models/Env/tall_grass.glb")
const FLOOR_TILE := preload("res://Assets/Models/Env/floor_tile.glb")

const COLORS := {
	Style.GRASS: [Color(0.2, 0.4, 0.12), Color(0.55, 0.37, 0.22), Color(0.42, 0.29, 0.19)],
	Style.STONE: [Color(0.52, 0.5, 0.55), Color(0.33, 0.31, 0.36), Color(0.22, 0.2, 0.25)],
	Style.WOOD: [Color(0.66, 0.45, 0.27), Color(0.5, 0.33, 0.2), Color(0.4, 0.26, 0.16)],
}

var _gen: Node3D
var _col: CollisionShape3D

func _ready():
	sync_to_physics = true
	_rebuild()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color):
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)

func _rebuild():
	if not is_inside_tree():
		return
	if _gen:
		_gen.queue_free()
	if _col:
		_col.queue_free()
	_gen = Node3D.new()
	_gen.name = "_Generated"
	add_child(_gen)

	var cols: Array = COLORS[style]
	var top_h := 0.3
	var body_h: float = max(size.y - top_h, 0.1)

	# Collision (must be a direct child of the physics body)
	_col = CollisionShape3D.new()
	_col.name = "_Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	_col.shape = shape
	_col.position = Vector3(0, -size.y / 2.0, 0)
	add_child(_col)

	if style == Style.WOOD:
		# Planks with small gaps
		var n: int = max(int(size.x / 0.6), 1)
		var w: float = size.x / n
		for i in n:
			var c: Color = cols[0] if i % 2 == 0 else cols[1]
			_box(_gen, Vector3(w - 0.06, size.y, size.z), Vector3(-size.x / 2.0 + w * (i + 0.5), -size.y / 2.0, 0), c)
		_box(_gen, Vector3(size.x + 0.1, 0.12, 0.25), Vector3(0, -size.y - 0.06, size.z / 2.0 - 0.3), cols[2])
		_box(_gen, Vector3(size.x + 0.1, 0.12, 0.25), Vector3(0, -size.y - 0.06, -size.z / 2.0 + 0.3), cols[2])
		return

	_box(_gen, Vector3(size.x + 0.12, top_h, size.z + 0.12), Vector3(0, -top_h / 2.0, 0), cols[0])
	_box(_gen, Vector3(size.x, body_h, size.z), Vector3(0, -top_h - body_h / 2.0, 0), cols[1])

	if island_bottom:
		# Upside-down square pyramid made from a 4-sided cylinder
		var depth: float = clamp(min(size.x, size.z) * 0.7, 1.0, 6.0)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.7071
		cm.bottom_radius = 0.05
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		cm.material = _mat(cols[2])
		mi.mesh = cm
		mi.basis = Basis.from_scale(Vector3(size.x, depth, size.z)) * Basis(Vector3.UP, PI / 4.0)
		mi.position = Vector3(0, -size.y - depth / 2.0, 0)
		_gen.add_child(mi)

	if not decorate:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(position.round()))
	if style == Style.GRASS:
		var count := int(size.x * size.z / 5.0)
		for i in count:
			var g: Node3D = (GRASS_TUFT if rng.randf() < 0.7 else TALL_GRASS).instantiate()
			g.position = Vector3(rng.randf_range(-0.45, 0.45) * size.x, 0, rng.randf_range(-0.45, 0.45) * size.z)
			g.rotation.y = rng.randf() * TAU
			g.scale = Vector3.ONE * rng.randf_range(0.35, 0.6)
			_gen.add_child(g)
	elif style == Style.STONE:
		# Floor tiles are 2x2; only tile blocks whose size fits the grid
		var nx := int(size.x / 2.0)
		var nz := int(size.z / 2.0)
		if nx * 2 == int(size.x) and nz * 2 == int(size.z) and nx * nz <= 64:
			for ix in nx:
				for iz in nz:
					var t: Node3D = FLOOR_TILE.instantiate()
					t.position = Vector3(-size.x / 2.0 + 1 + ix * 2, -0.1, -size.z / 2.0 + 1 + iz * 2)
					_gen.add_child(t)
