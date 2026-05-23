extends Camera2D

@export var player_path: NodePath = ^"../Player"
@export var look_ahead := 140.0
@export var follow_offset := Vector2.ZERO
## 0 = top of screen, 1 = bottom. ~0.82 keeps the zebra low with ground near the bottom edge.
@export_range(0.35, 0.95, 0.01) var player_screen_anchor := 0.82
@export var follow_speed := 8.0

var _player: Player


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	if _player:
		_snap_to_player()


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	var target := _get_target_position(_player.get_facing())
	var t := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target, t)


func _snap_to_player() -> void:
	global_position = _get_target_position(_player.get_facing())


func _get_target_position(facing: float) -> Vector2:
	var anchor := _player.get_camera_anchor_global_position()
	var viewport_height := get_viewport().get_visible_rect().size.y
	var zoom_y := zoom.y if zoom.y != 0.0 else 1.0

	# Place the feet anchor at player_screen_anchor on the screen (higher value = lower on screen).
	var camera_y := anchor.y - (player_screen_anchor - 0.5) * viewport_height / zoom_y
	# Camera shifts toward the facing side so more of the level is visible ahead of the zebra.
	var camera_x := anchor.x + facing * look_ahead + follow_offset.x

	return Vector2(camera_x, camera_y + follow_offset.y)
