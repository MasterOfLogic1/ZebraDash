class_name TerrainCatalog

enum TerrainStyle {
	LIGHT_GREEN_GRASS,
	DARK_GREEN_GRASS,
	LIGHT_GREEN_GRASS_LIGHT_ROCK,
}

const TILE_SIZE := Vector2i(128, 128)

const THEME_DIRS := {
	TerrainStyle.LIGHT_GREEN_GRASS: "res://Assets/terrain/light_green_grass/",
	TerrainStyle.DARK_GREEN_GRASS: "res://Assets/terrain/dark_green_grass/",
	TerrainStyle.LIGHT_GREEN_GRASS_LIGHT_ROCK: "res://Assets/terrain/light_green_grass_light_rock/",
}

const TOP_VARIANTS := [
	"top_1.png",
	"top_2.png",
	"top_3.png",
]

const FILL_TILE := "flat_color_inner_fill.png"

const ROCK_OBSTACLE_PIECES := [
	"one_edge_platform_rock_1.png",
	"one_edge_platform_rock_2.png",
	"left_edge_rock_1.png",
	"left_edge_rock_2.png",
	"right_edge_rock_1.png",
	"right_edge_rock_2.png",
]


static func get_theme_dir(style: TerrainStyle) -> String:
	return THEME_DIRS.get(style, THEME_DIRS[TerrainStyle.LIGHT_GREEN_GRASS])


static func tile_path(style: TerrainStyle, filename: String) -> String:
	return get_theme_dir(style) + filename


static func tileset_resource_path(style: TerrainStyle) -> String:
	match style:
		TerrainStyle.DARK_GREEN_GRASS:
			return "res://Assets/terrain/tilesets/dark_green_grass_tileset.tres"
		TerrainStyle.LIGHT_GREEN_GRASS_LIGHT_ROCK:
			return "res://Assets/terrain/tilesets/light_green_grass_light_rock_tileset.tres"
		_:
			return "res://Assets/terrain/tilesets/light_green_grass_tileset.tres"


static func build_tileset(style: TerrainStyle) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var source_id := 0
	for top_name in TOP_VARIANTS:
		_add_tile_source(tile_set, source_id, tile_path(style, top_name))
		source_id += 1

	_add_tile_source(tile_set, source_id, tile_path(style, FILL_TILE))

	return tile_set


static func get_top_source_ids() -> Array[int]:
	return [0, 1, 2]


static func get_fill_source_id() -> int:
	return TOP_VARIANTS.size()


static func _add_tile_source(tile_set: TileSet, source_id: int, texture_path: String) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("TerrainCatalog: missing texture %s" % texture_path)
		return

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = TILE_SIZE
	atlas.create_tile(Vector2i(0, 0))

	# Tile physics coordinates use the top-left of each cell as origin.
	var tile_data := atlas.get_tile_data(Vector2i(0, 0), 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(
		0,
		0,
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(TILE_SIZE.x, 0),
			Vector2(TILE_SIZE),
			Vector2(0, TILE_SIZE.y),
		])
	)

	tile_set.add_source(atlas, source_id)
