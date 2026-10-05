extends Node

# ---------- VARIABLES ---------- #

# References
@onready var jump_sfx = $JumpSfx
@onready var coin_sfx = $CoinSfx

# Extra one-shot players re-using the kit's sounds at different pitches
var hurt_sfx := AudioStreamPlayer.new()
var door_sfx := AudioStreamPlayer.new()
var bounce_sfx := AudioStreamPlayer.new()

# ---------- FUNCTIONS ---------- #

func _ready():
	hurt_sfx.stream = jump_sfx.stream
	hurt_sfx.pitch_scale = 0.45
	hurt_sfx.volume_db = 0.0
	door_sfx.stream = coin_sfx.stream
	door_sfx.pitch_scale = 0.6
	bounce_sfx.stream = jump_sfx.stream
	bounce_sfx.pitch_scale = 1.6
	for p in [hurt_sfx, door_sfx, bounce_sfx]:
		add_child(p)

func play_hurt():
	hurt_sfx.play()

func play_door():
	door_sfx.play()

func play_bounce():
	bounce_sfx.play()
