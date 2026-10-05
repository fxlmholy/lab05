extends Area3D

# Hurts the player on touch (saw blades, spiky balls, spikes...).

@export var enabled := true

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	# Also catch a player who is still standing inside after their invincibility ran out
	if enabled:
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _on_body_entered(body):
	if enabled and body.is_in_group("Player") and body.has_method("hurt"):
		body.hurt(global_position)
