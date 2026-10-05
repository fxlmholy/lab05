extends Node3D

# Exit door. Stays locked until every star in the level is collected,
# then swings open and sends the player to the next level.

@onready var hinge: Node3D = $Hinge
@onready var blocker: CollisionShape3D = $Blocker/CollisionShape3D
@onready var exit_area: Area3D = $ExitArea
@onready var label: Label3D = $Label3D
@onready var light: OmniLight3D = $Light

var is_open := false
var used := false

func _ready():
	GameManager.stats_changed.connect(_update_label)
	GameManager.all_collected.connect(open)
	exit_area.body_entered.connect(_on_exit_entered)
	light.visible = false
	_update_label.call_deferred()

func _update_label():
	if is_open:
		return
	label.text = "LOCKED\n%d / %d STARS" % [GameManager.score, GameManager.total]

func open():
	if is_open:
		return
	is_open = true
	label.text = "ENTER!"
	label.modulate = Color(1, 0.9, 0.3)
	light.visible = true
	blocker.set_deferred("disabled", true)
	AudioManager.play_door()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hinge, "rotation_degrees:y", -105.0, 1.0)

func _on_exit_entered(body):
	if not is_open or used or not body.is_in_group("Player"):
		return
	used = true
	if body.has_method("celebrate"):
		body.celebrate()
	GameManager.show_message.emit("Level complete!")
	await get_tree().create_timer(1.6).timeout
	GameManager.next_level()
