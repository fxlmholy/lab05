extends Node3D

@onready var pivot: Node3D = $CameraPivot
@onready var anim: AnimationPlayer = $Character/AnimationPlayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim.play("Victory")
	var t := int(GameManager.run_time)
	$UI/Center/VBox/Stats.text = "Stars collected: %d\nLives lost: %d\nTime: %d:%02d" % [
		GameManager.total_score, GameManager.deaths, t / 60, t % 60]
	$UI/Center/VBox/Again.pressed.connect(GameManager.new_game)
	$UI/Center/VBox/Menu.pressed.connect(GameManager.go_to_menu)
	$UI/Center/VBox/Again.grab_focus()

func _process(delta):
	pivot.rotate_y(delta * 0.3)
