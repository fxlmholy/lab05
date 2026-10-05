extends Node

# Moves its parent node. Add as a child of a platform or hazard.
# Works on AnimatableBody3D too, so moving platforms carry the player.

enum Mode { PING_PONG, ROTATE, PENDULUM }

@export var mode: Mode = Mode.PING_PONG
## PING_PONG: how far the parent travels from its start position
@export var offset := Vector3(4, 0, 0)
## PING_PONG / PENDULUM: seconds for one full back-and-forth cycle
@export var duration := 3.0
## ROTATE / PENDULUM: local axis to turn around
@export var axis := Vector3.UP
## ROTATE: degrees per second
@export var speed_deg := 90.0
## PENDULUM: max swing angle
@export var angle_deg := 60.0
## 0..1, shifts the cycle so several movers don't move in sync
@export_range(0.0, 1.0) var phase := 0.0

var _t := 0.0
var _start: Transform3D
var _target: Node3D

func _ready():
	_target = get_parent()
	_start = _target.transform
	_t = phase * duration

func _physics_process(delta):
	_t += delta
	match mode:
		Mode.PING_PONG:
			_target.position = _start.origin + offset * (0.5 - 0.5 * cos(TAU * _t / duration))
		Mode.ROTATE:
			_target.transform.basis = _start.basis * Basis(axis.normalized(), deg_to_rad(speed_deg) * _t)
		Mode.PENDULUM:
			_target.transform.basis = _start.basis * Basis(axis.normalized(), deg_to_rad(angle_deg) * sin(TAU * _t / duration))
