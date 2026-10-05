extends Area3D

# Bounce pad: launches the player high into the air.

@export var bounce_force := 17.0

@onready var anim: AnimationPlayer = get_parent().find_child("AnimationPlayer", true, false)

func _ready():
	body_entered.connect(_on_body_entered)
	anim.play("BouncerArmature|Bouncer_Idle")

func _on_body_entered(body):
	if body.is_in_group("Player") and body.has_method("bounce") and body.velocity.y <= 0.5:
		body.bounce(bounce_force)
		AudioManager.play_bounce()
		anim.play("BouncerArmature|Bouncer_Bounce")
		anim.queue("BouncerArmature|Bouncer_Idle")
