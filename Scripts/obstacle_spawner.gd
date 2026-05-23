@tool
extends Node2D

@export var player_path: NodePath = ^"../Player"
@export var ground_path: NodePath = ^"../Ground"
@export var camera_path: NodePath = ^"../Camera2D"
@export var obstacle_scene: PackedScene = preload("res://Scenes/obstacle.tscn")
@export var min_spawn_interval := 1.8
@export var max_spawn_interval := 4.5
@export var spawn_beyond_screen_min := 120.0
@export var spawn_beyond_screen_max := 420.0
@export var min_spacing := 280.0
@export var cleanup_behind_distance := 600.0
@export var show_editor_preview := true
@export_range(1, 8, 1) var min_pieces_horizontal := 1
@export_range(1, 8, 1) var max_pieces_horizontal := 3
@export_range(1, 4, 1) var min_pieces_vertical := 1
@export_range(1, 4, 1) var max_pieces_vertical := 2
@export var preview_pieces_horizontal := 2
@export var preview_pieces_vertical := 2

const TILE_SIZE := float(TerrainCatalog.TILE_SIZE.x)
const EDITOR_PREVIEW_NAME := "EditorPreview"

var _player: Player
var _ground: Node2D
var _camera: Camera2D
var _spawn_timer := 0.0
var _last_spawn_x := -INF


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_refresh_editor_preview")
		return

	_remove_editor_preview()
	_player = get_node_or_null(player_path) as Player
	_ground = get_node_or_null(ground_path) as Node2D
	_camera = get_node_or_null(camera_path) as Camera2D
	_reset_spawn_timer()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_try_spawn_obstacle()
		_reset_spawn_timer()

	_cleanup_obstacles()


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or get_tree() == null:
		return

	_remove_editor_preview()
	if not show_editor_preview or obstacle_scene == null:
		return

	var player := get_node_or_null(player_path) as Node2D
	var preview_x := 400.0
	if player:
		preview_x = player.global_position.x + 360.0

	var surface_y := _get_ground_surface_y_at(preview_x)
	var obstacle := obstacle_scene.instantiate()
	obstacle.name = EDITOR_PREVIEW_NAME
	_apply_terrain_style(obstacle)
	if obstacle.has_method("configure"):
		obstacle.configure(preview_pieces_horizontal, preview_pieces_vertical)
	obstacle.global_position = Vector2(preview_x, surface_y)
	add_child(obstacle)


func _remove_editor_preview() -> void:
	var preview := get_node_or_null(EDITOR_PREVIEW_NAME)
	if preview:
		preview.free()


func _try_spawn_obstacle() -> void:
	var spawn_x := _get_offscreen_spawn_x()
	if absf(spawn_x - _last_spawn_x) < min_spacing:
		return

	spawn_x = snappedf(spawn_x, TILE_SIZE)

	var surface_y := _get_ground_surface_y_at(spawn_x)
	var obstacle := obstacle_scene.instantiate()
	_apply_terrain_style(obstacle)
	if obstacle.has_method("configure"):
		obstacle.configure(
			randi_range(mini(min_pieces_horizontal, max_pieces_horizontal), maxi(min_pieces_horizontal, max_pieces_horizontal)),
			randi_range(mini(min_pieces_vertical, max_pieces_vertical), maxi(min_pieces_vertical, max_pieces_vertical))
		)
	obstacle.global_position = Vector2(spawn_x, surface_y)
	add_child(obstacle)
	_last_spawn_x = spawn_x


func _apply_terrain_style(obstacle: Node) -> void:
	if _ground == null:
		_ground = get_node_or_null(ground_path) as Node2D
	if _ground and "terrain_style" in _ground:
		obstacle.terrain_style = _ground.terrain_style


func _get_offscreen_spawn_x() -> float:
	var camera := _camera if _camera else get_viewport().get_camera_2d()
	if camera == null:
		return _player.global_position.x + spawn_beyond_screen_min

	var viewport_width := get_viewport().get_visible_rect().size.x
	var half_width := (viewport_width * 0.5) / camera.zoom.x
	var beyond := randf_range(spawn_beyond_screen_min, spawn_beyond_screen_max)

	var facing := _player.get_facing()
	if facing == 0.0:
		facing = signf(_player.velocity.x)
	if facing == 0.0:
		facing = 1.0

	if facing > 0.0:
		var right_edge := camera.global_position.x + half_width
		return right_edge + beyond

	var left_edge := camera.global_position.x - half_width
	return left_edge - beyond


func _get_ground_surface_y_at(world_x: float) -> float:
	var ground := _ground if _ground else get_node_or_null(ground_path) as Node2D
	if ground and ground.has_node("GroundLayer"):
		var layer := ground.get_node("GroundLayer") as TileMapLayer
		var local_x := layer.to_local(Vector2(world_x, 0.0)).x
		var cell_x := int(floor(local_x / TILE_SIZE))
		return layer.to_global(Vector2(cell_x * TILE_SIZE, 0)).y
	if ground:
		return ground.global_position.y
	if _player:
		return _player.global_position.y
	return 0.0


func _cleanup_obstacles() -> void:
	var facing := _player.get_facing()
	if facing == 0.0:
		facing = signf(_player.velocity.x)
	if facing == 0.0:
		facing = 1.0

	for child in get_children():
		if child.name == EDITOR_PREVIEW_NAME:
			continue
		if child is StaticBody2D:
			var behind: bool = child.global_position.x < _player.global_position.x - cleanup_behind_distance
			if facing < 0.0:
				behind = child.global_position.x > _player.global_position.x + cleanup_behind_distance
			if behind:
				child.queue_free()


func _reset_spawn_timer() -> void:
	_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)
