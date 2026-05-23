@tool
extends Node2D

@export var player_path: NodePath = ^"../Player"
@export var ground_path: NodePath = ^"../Ground"
@export var camera_path: NodePath = ^"../Camera2D"
## One scene per obstacle design — open these under Scenes/obstacles/ to edit.
@export var obstacle_scenes: Array[PackedScene] = [
	preload("res://Scenes/obstacles/berm_small.tscn"),
	preload("res://Scenes/obstacles/berm_wide.tscn"),
	preload("res://Scenes/obstacles/wall_low.tscn"),
	preload("res://Scenes/obstacles/floating_platform.tscn"),
]
@export var preview_scene_index := 2
@export var min_spawn_interval := 2.0
@export var max_spawn_interval := 4.5
@export var spawn_beyond_screen_min := 120.0
@export var spawn_beyond_screen_max := 420.0
@export var min_spacing := 320.0
@export var cleanup_behind_distance := 700.0
@export var max_active_obstacles := 24
@export var show_editor_preview := true
## Slight bury into runway grass art (keep small now that obstacles have tall bodies below).
@export_range(0.0, 64.0, 1.0) var ground_overlap_pixels := 4.0

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
	if not show_editor_preview or obstacle_scenes.is_empty():
		return

	var player := get_node_or_null(player_path) as Node2D
	var preview_x := 400.0
	if player:
		preview_x = player.global_position.x + 400.0

	var index := clampi(preview_scene_index, 0, obstacle_scenes.size() - 1)
	_spawn_scene_at(preview_x, obstacle_scenes[index], EDITOR_PREVIEW_NAME)


func _remove_editor_preview() -> void:
	var preview := get_node_or_null(EDITOR_PREVIEW_NAME)
	if preview:
		preview.free()


func _try_spawn_obstacle() -> void:
	if obstacle_scenes.is_empty():
		return
	if _count_active_obstacles() >= max_active_obstacles:
		_cleanup_obstacles()
		if _count_active_obstacles() >= max_active_obstacles:
			return

	var spawn_x := _get_offscreen_spawn_x()
	if absf(spawn_x - _last_spawn_x) < min_spacing:
		return

	spawn_x = snappedf(spawn_x, TILE_SIZE)
	var scene := obstacle_scenes[randi() % obstacle_scenes.size()]
	_spawn_scene_at(spawn_x, scene)


func _spawn_scene_at(spawn_x: float, scene: PackedScene, custom_name: String = "") -> void:
	if scene == null:
		return

	var tile_top_y := _get_ground_tile_top_y_at(spawn_x)
	var obstacle := scene.instantiate()
	if custom_name != "":
		obstacle.name = custom_name

	var spawn_y := tile_top_y
	if obstacle.has_method("is_floating") and obstacle.is_floating():
		var elevation := 0
		if "elevation_tiles" in obstacle:
			elevation = obstacle.elevation_tiles
		spawn_y -= float(elevation) * TILE_SIZE
	else:
		var bottom_y := 0.0
		if obstacle.has_method("get_bottom_extent_y"):
			bottom_y = obstacle.get_bottom_extent_y()
		var attach_offset := 0.0
		if "ground_attach_offset" in obstacle:
			attach_offset = obstacle.ground_attach_offset
		var grass_line_y := tile_top_y + TerrainCatalog.RUNWAY_GRASS_LINE_Y
		spawn_y = grass_line_y - bottom_y + ground_overlap_pixels - attach_offset

	obstacle.global_position = Vector2(spawn_x, spawn_y)
	add_child(obstacle)

	if obstacle.has_method("get_spawn_width"):
		_last_spawn_x = spawn_x + obstacle.get_spawn_width()
	else:
		_last_spawn_x = spawn_x


func _count_active_obstacles() -> int:
	var count := 0
	for child in get_children():
		if child.name == EDITOR_PREVIEW_NAME:
			continue
		if child is StaticBody2D and is_instance_valid(child):
			count += 1
	return count


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


func _get_ground_tile_top_y_at(world_x: float) -> float:
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

	var to_remove: Array[Node] = []
	for child in get_children():
		if child.name == EDITOR_PREVIEW_NAME:
			continue
		if not child is StaticBody2D or not is_instance_valid(child):
			continue
		var behind: bool = child.global_position.x < _player.global_position.x - cleanup_behind_distance
		if facing < 0.0:
			behind = child.global_position.x > _player.global_position.x + cleanup_behind_distance
		if behind:
			to_remove.append(child)

	for child in to_remove:
		child.queue_free()


func _reset_spawn_timer() -> void:
	_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)
