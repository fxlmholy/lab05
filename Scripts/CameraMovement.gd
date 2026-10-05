# ----------------------------------------------------------------------------------- #
# -------------- FEEL FREE TO USE IN ANY PROJECT, COMMERCIAL OR NON-COMMERCIAL ------ #
# ---------------------- 3D PLATFORMER CONTROLLER BY SD STUDIOS --------------------- #
# ---------------------------- ATTRIBUTION NOT REQUIRED ----------------------------- #
# ----------------------------------------------------------------------------------- #

extends Node3D

# ---------- VARIABLES ---------- #

# Control Mouse Sensitivity through inspector or from here
@export var mouse_sensitivity := 0.2
## Degrees per second when turning the camera with the arrow keys
@export var key_turn_speed := 120.0

# Assign Camera Node here it might be named different in your Project
@onready var camera = $Camera3D
@onready var auto_rotate = false
@onready var timer = $CameraControlTimer

# ---------- FUNCTIONS ---------- #

func _ready():
	top_level = true
	if not timer.timeout.is_connected(_on_camera_control_timer_timeout):
		timer.timeout.connect(_on_camera_control_timer_timeout)
	# Confining Mouse Cursor in the game view so it doesnt get in the way of gameplay
	timer.start()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	# Arrow keys also turn the camera (handy on laptops and in the browser)
	var turn := Input.get_axis("camera_right", "camera_left")
	var tilt := Input.get_axis("camera_down", "camera_up")
	if turn != 0 or tilt != 0:
		rotation_degrees.y = wrapf(rotation_degrees.y + turn * key_turn_speed * delta, 0, 360)
		rotation_degrees.x = clamp(rotation_degrees.x + tilt * key_turn_speed * 0.5 * delta, -60, 0)
		auto_rotate = false
		timer.start()

# Handling Camera Movement
func _unhandled_input(event):
	# Browsers only allow pointer lock after a click
	if event is InputEventMouseButton and event.pressed and not get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -60, -0)

		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.y = wrapf(rotation_degrees.y, 0, 360)
		auto_rotate = false
		timer.start()


func _on_camera_control_timer_timeout():
	auto_rotate = true
