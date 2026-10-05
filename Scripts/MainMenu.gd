extends Node3D

# Title screen: a rotating camera around the character plus Start / Quit buttons.

@onready var pivot: Node3D = $CameraPivot
@onready var anim: AnimationPlayer = $Character/AnimationPlayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	anim.play("Idle")
	$UI/Center/VBox/Start.pressed.connect(GameManager.new_game)
	$UI/Center/VBox/Quit.pressed.connect(get_tree().quit)
	$UI/Center/VBox/Start.grab_focus()
	# Quitting makes no sense in a browser tab
	$UI/Center/VBox/Quit.visible = not OS.has_feature("web")

func _process(delta):
	pivot.rotate_y(delta * 0.25)
