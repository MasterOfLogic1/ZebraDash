@tool
extends Node2D

@export var player_path: NodePath = ^"../Player"
@export var terrain_style: TerrainCatalog.TerrainStyle = TerrainCatalog.TerrainStyle.LIGHT_GREEN_GRASS
@export var buffer_tiles_ahead := 45
@export var buffer_tiles_behind := 20
@export var cleanup_extra_tiles := 25
## Dirt/fill rows below the grass surface (each row is one terrain tile tall).
@export_range(1, 12, 1) var ground_fill_depth_tiles := 4

@onready var ground_layer: TileMapLayer = $GroundLayer

const TILE_SIZE: Vector2i = TerrainCatalog.TILE_SIZE

var _player: Node2D
var _generated_min := 0
var _generated_max := -1
var _fill_source_id := TerrainCatalog.get_fill_source_id()
var _top_source_ids: Array[int] = TerrainCatalog.get_top_source_ids()


func _ready() -> void:
	if not Engine.is_editor_hint():
		_player = get_node_or_null(player_path) as Node2D
	_setup_ground()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _player == null or ground_layer == null:
		return
	_update_infinite_ground()


func _setup_ground() -> void:
	if ground_layer == null:
		return

	ground_layer.tile_set = _get_or_create_tileset()
	ground_layer.collision_enabled = true

	if not Engine.is_editor_hint():
		ground_layer.clear()

	var center := 0
	if not Engine.is_editor_hint() and _player:
		center = _get_player_tile_x()
	elif Engine.is_editor_hint():
		center = 32

	_generated_min = center - buffer_tiles_behind
	_generated_max = center + buffer_tiles_ahead
	for x in range(_generated_min, _generated_max + 1):
		_set_ground_column(x)
	ground_layer.update_internals()


func _update_infinite_ground() -> void:
	var center := _get_player_tile_x()
	var want_min := center - buffer_tiles_behind
	var want_max := center + buffer_tiles_ahead

	for x in range(want_min, want_max + 1):
		if x < _generated_min or x > _generated_max:
			_set_ground_column(x)

	_generated_min = mini(_generated_min, want_min)
	_generated_max = maxi(_generated_max, want_max)

	var erase_before := want_min - cleanup_extra_tiles
	while _generated_min < erase_before:
		_erase_ground_column(_generated_min)
		_generated_min += 1

	var erase_after := want_max + cleanup_extra_tiles
	while _generated_max > erase_after:
		_erase_ground_column(_generated_max)
		_generated_max -= 1


func _get_player_tile_x() -> int:
	var local_pos := ground_layer.to_local(_player.global_position)
	return int(floor(local_pos.x / float(TILE_SIZE.x)))


func _set_ground_column(x: int) -> void:
	if ground_layer.get_cell_source_id(Vector2i(x, 0)) == -1:
		var top_source := _top_source_ids[randi() % _top_source_ids.size()]
		ground_layer.set_cell(Vector2i(x, 0), top_source, Vector2i.ZERO)

	for y in range(1, ground_fill_depth_tiles + 1):
		var coords := Vector2i(x, y)
		if ground_layer.get_cell_source_id(coords) == -1:
			ground_layer.set_cell(coords, _fill_source_id, Vector2i.ZERO)


func _erase_ground_column(x: int) -> void:
	for y in range(0, ground_fill_depth_tiles + 1):
		ground_layer.erase_cell(Vector2i(x, y))


func _get_or_create_tileset() -> TileSet:
	var tileset_path := TerrainCatalog.tileset_resource_path(terrain_style)
	if ResourceLoader.exists(tileset_path):
		var saved := load(tileset_path) as TileSet
		if _tileset_has_collision(saved):
			return saved

	# Stale tileset on disk (saved without physics) — remove so we rebuild once.
	if FileAccess.file_exists(tileset_path):
		DirAccess.remove_absolute(tileset_path)

	DirAccess.make_dir_recursive_absolute("res://Assets/terrain/tilesets")
	var tile_set := TerrainCatalog.build_tileset(terrain_style)
	ResourceSaver.save(tile_set, tileset_path)
	return tile_set


func _tileset_has_collision(tile_set: TileSet) -> bool:
	if tile_set == null or tile_set.get_physics_layers_count() == 0:
		return false
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source == null or not source.has_tile(Vector2i.ZERO):
		return false
	var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
	return tile_data.get_collision_polygons_count(0) > 0
