@tool
class_name Player
extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -520.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var gallop_audio: AudioStreamPlayer2D = $GallopAudio
@onready var neigh_audio: AudioStreamPlayer2D = $NeighAudio

var _facing := 1.0


func get_facing() -> float:
	return _facing


func get_camera_anchor_global_position() -> Vector2:
	var collision := $CollisionShape2D as CollisionShape2D
	if collision == null or collision.shape == null:
		return global_position

	var half_height := 0.0
	if collision.shape is RectangleShape2D:
		half_height = (collision.shape as RectangleShape2D).size.y * 0.5
	elif collision.shape is CircleShape2D:
		half_height = (collision.shape as CircleShape2D).radius

	return collision.global_position + Vector2(0.0, half_height)


func _ready() -> void:
	_setup_sprite()
	_setup_gallop_audio()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_neigh()

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation(direction)
	_update_gallop_audio(direction)


func _setup_sprite() -> void:
	if animated_sprite == null:
		return
	animated_sprite.sprite_frames = _build_sprite_frames()
	animated_sprite.play("idle")


func _setup_gallop_audio() -> void:
	if gallop_audio == null:
		return
	var stream := load("res://Assets/audio/galloping.mp3") as AudioStreamMP3
	if stream:
		stream.loop = true
		gallop_audio.stream = stream


func _play_neigh() -> void:
	if neigh_audio and neigh_audio.stream:
		neigh_audio.play()


func _update_gallop_audio(direction: float) -> void:
	if gallop_audio == null:
		return

	var moving := is_on_floor() and absf(velocity.x) > 5.0 and direction != 0.0
	if moving:
		if not gallop_audio.playing:
			gallop_audio.play()
	elif gallop_audio.playing:
		gallop_audio.stop()


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_animation(frames, "idle", "res://Assets/player/__zebra_idle_", 0, 19, 8.0)
	_add_animation(frames, "run", "res://Assets/player/__zebra_run_", 0, 7, 14.0)
	_add_animation(frames, "jump", "res://Assets/player/__zebra_run_jump_", 0, 12, 12.0)
	return frames


func _add_animation(
	frames: SpriteFrames,
	anim_name: StringName,
	path_prefix: String,
	start: int,
	end: int,
	speed: float
) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, true)
	for i in range(start, end + 1):
		var path := path_prefix + "%03d" % i + ".png"
		if ResourceLoader.exists(path):
			frames.add_frame(anim_name, load(path) as Texture2D)


func _update_animation(direction: float) -> void:
	var anim: StringName = &"idle"
	if not is_on_floor():
		anim = &"jump"
	elif absf(velocity.x) > 5.0:
		anim = &"run"

	if animated_sprite.animation != anim:
		animated_sprite.play(anim)

	var facing := direction if direction != 0.0 else signf(velocity.x)
	if facing != 0.0:
		_facing = facing
		animated_sprite.flip_h = facing > 0.0
