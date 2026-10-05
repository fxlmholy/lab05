# ----------------------------------------------------------------------------------- #
# -------------- FEEL FREE TO USE IN ANY PROJECT, COMMERCIAL OR NON-COMMERCIAL ------ #
# ---------------------- 3D PLATFORMER CONTROLLER BY SD STUDIOS --------------------- #
# ---------------------------- ATTRIBUTION NOT REQUIRED ----------------------------- #
# ----------------------------------------------------------------------------------- #
# Modified for lab05: new character model from Poly Pizza, physics-step movement so moving
# platforms carry the player, fall/land animations, damage, lives and checkpoints.

extends CharacterBody3D

# ---------- VARIABLES ---------- #

@export_category("Player Properties")
@export var move_speed : float = 6
@export var jump_force : float = 8
@export var follow_lerp_factor : float = 4
@export var jump_limit : int = 2

@export_group("Game Juice")
@export var jumpStretchSize := Vector3(0.8, 1.2, 0.8)
@export var knockback_force := 4.5
@export var invincible_time := 1.5

# Booleans
var is_grounded = false
var can_double_jump = false
var is_flipping = false
var was_grounded = true

# Damage state
var invincible := 0.0
var stun := 0.0
var is_dead := false
var spawn_position := Vector3.ZERO

# Onready Variables
@onready var model = $Model
@onready var flip_pivot = $Model/FlipPivot
@onready var animation = $Model/AnimationPlayer
@onready var spring_arm = %Gimbal

@onready var particle_trail = $ParticleTrail
@onready var footsteps = $Footsteps

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

# ---------- FUNCTIONS ---------- #

func _ready():
	spawn_position = global_position
	spring_arm.global_position = global_position

func _physics_process(delta):
	invincible = max(invincible - delta, 0.0)
	stun = max(stun - delta, 0.0)
	model.visible = invincible <= 0.0 or int(invincible * 12) % 2 == 0

	get_input(delta)
	player_animations()

	# Smoothly follow player's position
	spring_arm.position = lerp(spring_arm.position, global_position, delta * follow_lerp_factor)

	# Player Rotation
	if is_moving() and stun <= 0.0:
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)
		if spring_arm.auto_rotate:
			spring_arm.rotation.y = lerp_angle(spring_arm.rotation.y, look_direction.angle()-deg_to_rad(180), delta*0.4)
			spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x, deg_to_rad(-12), delta*0.4)

	# Check if player is grounded or not
	is_grounded = is_on_floor()

	# Handle Jumping
	if is_grounded:
		can_double_jump = true
		if not was_grounded:
			land()
	was_grounded = is_grounded

	if Input.is_action_just_pressed("jump") and not is_dead and stun <= 0.0:
		if is_on_floor():
			perform_jump()
		elif can_double_jump:
			perform_flip_jump()

	velocity.y -= gravity * delta

func perform_jump():
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 1.12

	jumpTween()
	animation.play("Jump")
	velocity.y = jump_force

func perform_flip_jump():
	can_double_jump = false
	is_flipping = true
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 0.8
	animation.play("Flip", -1, 1.6)
	velocity.y = jump_force
	await animation.animation_finished
	is_flipping = false
	flip_pivot.rotation = Vector3.ZERO
	if not is_on_floor():
		animation.play("Fall")

# Springs call this to launch the player into the air
func bounce(force: float):
	velocity.y = force
	can_double_jump = true
	jumpTween()
	animation.play("Jump")

func land():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12)

func is_moving():
	return abs(velocity.z) > 0.1 || abs(velocity.x) > 0.1

func jumpTween():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", jumpStretchSize, 0.1)
	tween.tween_property(self, "scale", Vector3(1,1,1), 0.1)

# Get Player Input
func get_input(_delta):
	if stun > 0.0 or is_dead:
		# Keep sliding with the knockback and only fight it with friction
		velocity.x = move_toward(velocity.x, 0, 10 * _delta)
		velocity.z = move_toward(velocity.z, 0, 10 * _delta)
		move_and_slide()
		return

	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_axis("move_left", "move_right")
	move_direction.z = Input.get_axis("move_forward", "move_back")

	# Move The player Towards Spring Arm/Camera Rotation
	move_direction = move_direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	velocity = Vector3(move_direction.x * move_speed, velocity.y, move_direction.z * move_speed)

	move_and_slide()

# Handle Player Animations
func player_animations():
	particle_trail.emitting = false
	footsteps.stream_paused = true

	if is_flipping or is_dead or stun > 0.0:
		return

	if is_on_floor():
		if is_moving(): # Checks if player is moving
			animation.play("Run", 0.3)
			particle_trail.emitting = true
			footsteps.stream_paused = false
		else:
			animation.play("Idle", 0.3)
	elif velocity.y < -2.0 and animation.current_animation != "Jump":
		animation.play("Fall", 0.3)

# ---------- DAMAGE ---------- #

# Called by hazards. Knocks the player away from the hazard and removes a life.
func hurt(from_position: Vector3):
	if invincible > 0.0 or is_dead:
		return
	invincible = invincible_time
	stun = 0.45
	AudioManager.play_hurt()
	animation.play("Hurt")
	var away := global_position - from_position
	away.y = 0
	if away.length() < 0.01:
		away = -model.global_transform.basis.z
	away = away.normalized() * knockback_force
	velocity = Vector3(away.x, 6.0, away.z)
	if not GameManager.lose_life():
		game_over()

# Called by the dead zone under the level
func fell():
	if is_dead:
		return
	AudioManager.play_hurt()
	if GameManager.lose_life():
		respawn()
	else:
		game_over()

func respawn():
	velocity = Vector3.ZERO
	global_position = spawn_position
	spring_arm.global_position = spawn_position
	invincible = invincible_time
	animation.play("Idle")

func set_checkpoint(pos: Vector3):
	spawn_position = pos

func game_over():
	is_dead = true
	velocity = Vector3.ZERO
	animation.play("Death")
	GameManager.show_message.emit("Out of lives! Restarting level...")
	await get_tree().create_timer(2.0).timeout
	GameManager.restart_level()

func celebrate():
	is_dead = true # freezes input
	velocity = Vector3.ZERO
	animation.play("Victory")
