extends Area3D

# ---------- SIGNALS ---------- #

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Player fell off the level: lose a life and go back to the last checkpoint
	if body.is_in_group("Player") and body.has_method("fell"):
		body.fell()
