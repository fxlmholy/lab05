extends Node

# ---------- SIGNALS ---------- #

signal stats_changed
signal all_collected
signal show_message(text: String)

# ---------- VARIABLES ---------- #

const LEVELS := [
	"res://Scenes/Levels/Level1.tscn",
	"res://Scenes/Levels/Level2.tscn",
]
const MENU_SCENE := "res://Scenes/UI/MainMenu.tscn"
const WIN_SCENE := "res://Scenes/UI/WinScreen.tscn"
const MAX_LIVES := 5

var score := 0         # items collected in the current level
var total := 0         # items that exist in the current level
var lives := MAX_LIVES
var level_index := 0
var total_score := 0   # items collected across finished levels
var deaths := 0
var run_time := 0.0
var timer_running := false

# ---------- FUNCTIONS ---------- #

func _ready():
	get_tree().node_added.connect(_on_node_added)

# The nature models (leaves, flowers) use alpha-blended materials, which sort badly and
# break shadows in the Compatibility renderer. Switch them to alpha scissor once.
func _on_node_added(node: Node):
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var m = node.mesh.surface_get_material(i)
			if m is BaseMaterial3D and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4

func _process(delta):
	show_mouse_cursor()
	if timer_running:
		run_time += delta

# Making Cursor visible using "mouse_visible" key which is assigned in Project Settings > Input Map
func show_mouse_cursor():
	if Input.is_action_just_pressed("mouse_visible"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Called by every collectible in its _ready so a level always knows how many items it has
func register_collectible():
	total += 1
	stats_changed.emit()

func add_score():
	score += 1
	stats_changed.emit()
	if score >= total:
		all_collected.emit()
		show_message.emit("All stars collected! The door is open!")
	else:
		show_message.emit("%d more to go" % (total - score))

func is_door_open() -> bool:
	return total > 0 and score >= total

# Returns false when the player is out of lives
func lose_life() -> bool:
	lives -= 1
	deaths += 1
	stats_changed.emit()
	return lives > 0

func new_game():
	total_score = 0
	deaths = 0
	run_time = 0.0
	start_level(0)

func start_level(index: int):
	level_index = index
	_reset_level_state()
	get_tree().change_scene_to_file(LEVELS[index])

func restart_level():
	start_level(level_index)

func next_level():
	total_score += score
	if level_index + 1 < LEVELS.size():
		start_level(level_index + 1)
	else:
		timer_running = false
		get_tree().change_scene_to_file(WIN_SCENE)

func go_to_menu():
	timer_running = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MENU_SCENE)

# Levels call this from their own _ready so they also work when run directly with F6
func level_started(index: int):
	level_index = index
	timer_running = true

func _reset_level_state():
	score = 0
	total = 0
	lives = MAX_LIVES
