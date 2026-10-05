extends Control

# ---------- VARIABLES ---------- #

@onready var coinsLabel = $TopBar/CoinsLabel
@onready var livesLabel = $TopBar/LivesLabel
@onready var levelLabel = $LevelTitle
@onready var messageLabel = $Message
@onready var pausePanel = $PausePanel

var _msg_tween: Tween

# ---------- FUNCTIONS ---------- #

func _ready():
	GameManager.stats_changed.connect(_refresh)
	GameManager.show_message.connect(_on_message)
	messageLabel.modulate.a = 0.0
	pausePanel.visible = false
	$PausePanel/VBox/Resume.pressed.connect(_toggle_pause)
	$PausePanel/VBox/Restart.pressed.connect(func(): get_tree().paused = false; GameManager.restart_level())
	$PausePanel/VBox/Menu.pressed.connect(func(): get_tree().paused = false; GameManager.go_to_menu())
	_refresh()

func _process(_delta):
	coinsLabel.text = "x %d / %d" % [GameManager.score, GameManager.total] # Set the coin label text to the score variable

func _refresh():
	livesLabel.text = "x %d" % max(GameManager.lives, 0)

func show_level_title(title: String, subtitle: String):
	levelLabel.text = "%s\n%s" % [title, subtitle]
	levelLabel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(levelLabel, "modulate:a", 0.0, 1.0)

func _on_message(text: String):
	messageLabel.text = text
	if _msg_tween:
		_msg_tween.kill()
	messageLabel.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.8)
	_msg_tween.tween_property(messageLabel, "modulate:a", 0.0, 0.6)

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		_toggle_pause()

func _toggle_pause():
	var p := not get_tree().paused
	get_tree().paused = p
	pausePanel.visible = p
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED)
