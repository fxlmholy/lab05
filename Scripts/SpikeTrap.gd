extends Node3D

# Floor trap: spikes pop out on a timer and only hurt while they are up.

@export var interval := 2.4      ## seconds between activations
@export_range(0.0, 1.0) var phase := 0.0
@export_range(0.0, 1.0) var danger_start := 0.15  ## part of the animation where spikes are out
@export_range(0.0, 1.0) var danger_end := 0.8

@onready var hazard: Area3D = $Hazard
@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

var _t := 0.0
var _length := 1.0
const ANIM := "Hazard_SpikeTrap_Armature|SpikeTrap_Activate"

func _ready():
	_t = phase * interval
	_length = anim.get_animation(ANIM).length
	anim.get_animation(ANIM).loop_mode = Animation.LOOP_NONE
	hazard.enabled = false

func _physics_process(delta):
	_t += delta
	if _t >= interval:
		_t -= interval
		anim.play(ANIM)
	var p := _t / _length
	hazard.enabled = p >= danger_start and p <= danger_end
