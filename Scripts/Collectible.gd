extends Area3D

# A star the player must collect. Based on the kit's Coin.gd (hover, spin and magnet).

# ---------- VARIABLES ---------- #

@export_category("Properties")
@export var follow_speed := 8.0
@export var amplitude := 0.2
@export var frequency := 3.0
@export var spin_speed := 120.0 # degrees per second

var time_passed = 0.0
var is_in_range = false
var collected = false
var initial_position := Vector3.ZERO

@onready var player := get_tree().get_first_node_in_group("Player")

# ---------- FUNCTIONS ---------- #

func _ready():
	initial_position = position
	time_passed = randf() * TAU # so stars don't bob in sync
	GameManager.register_collectible()
	body_entered.connect(_on_body_entered)
	$Range.body_entered.connect(_on_range_body_entered)

func _process(delta):
	rotate_y(deg_to_rad(spin_speed) * delta)
	if is_in_range and player:
		position += global_position.direction_to(player.global_position + Vector3.UP * 0.8) * follow_speed * delta
	else:
		time_passed += delta
		position.y = initial_position.y + amplitude * sin(frequency * time_passed)

# ---------- SIGNALS ---------- #

func _on_body_entered(body):
	if collected or not body.is_in_group("Player"):
		return
	collected = true
	GameManager.add_score()
	AudioManager.coin_sfx.play()
	set_deferred("monitoring", false)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.6, 0.08)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
	tween.tween_callback(queue_free)

func _on_range_body_entered(body):
	if body.is_in_group("Player"):
		is_in_range = true
