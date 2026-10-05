extends Area3D

# Flag that saves the player's respawn point when touched.

var activated := false

@onready var flag: Node3D = $Flag
@onready var spawn: Marker3D = $SpawnPoint

func _ready():
	body_entered.connect(_on_body_entered)
	flag.scale = Vector3(1, 0.4, 1)  # lowered until reached

func _on_body_entered(body):
	if activated or not body.is_in_group("Player"):
		return
	activated = true
	body.set_checkpoint(spawn.global_position)
	AudioManager.coin_sfx.pitch_scale = 0.9
	AudioManager.coin_sfx.play()
	GameManager.show_message.emit("Checkpoint!")
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flag, "scale", Vector3.ONE, 0.5)
