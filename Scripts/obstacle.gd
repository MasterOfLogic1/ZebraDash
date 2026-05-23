extends StaticBody2D

## Used by the spawner to place floating platforms above the runway.
@export_range(0, 8, 1) var elevation_tiles := 0
## Extra lift (pixels) so grounded obstacles sit higher on the runway grass line.
@export_range(-64.0, 128.0, 1.0) var ground_attach_offset := 0.0


func get_bottom_extent_y() -> float:
	var bottom := 0.0
	for child in get_children():
		if child is Sprite2D:
			var height := float(TerrainCatalog.TILE_SIZE.y)
			if child.texture:
				height = child.texture.get_height() * child.scale.y
			bottom = maxf(bottom, child.position.y + height)
	return bottom


func is_floating() -> bool:
	return elevation_tiles > 0


func get_spawn_width() -> float:
	var max_right := 0.0
	for child in get_children():
		if child is Sprite2D:
			var tex_width := TerrainCatalog.TILE_SIZE.x
			if child.texture:
				tex_width = child.texture.get_width() * child.scale.x
			max_right = maxf(max_right, child.position.x + tex_width)
	return maxf(max_right, float(TerrainCatalog.TILE_SIZE.x))
