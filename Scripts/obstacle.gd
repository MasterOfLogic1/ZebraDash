@tool
extends StaticBody2D

@export var terrain_style: TerrainCatalog.TerrainStyle = TerrainCatalog.TerrainStyle.LIGHT_GREEN_GRASS
@export_range(1, 8, 1) var pieces_horizontal := 2
@export_range(1, 4, 1) var pieces_vertical := 1

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _piece_size := Vector2(TerrainCatalog.TILE_SIZE)


func _ready() -> void:
	_build_obstacle()


func configure(horizontal: int, vertical: int) -> void:
	pieces_horizontal = clampi(horizontal, 1, 8)
	pieces_vertical = clampi(vertical, 1, 4)
	if is_inside_tree():
		_build_obstacle()


func get_footprint_size() -> Vector2:
	return Vector2(_piece_size.x * pieces_horizontal, _piece_size.y * pieces_vertical)


func _pick_rock_texture() -> Texture2D:
	var pieces := TerrainCatalog.ROCK_OBSTACLE_PIECES
	var filename: String = pieces[randi() % pieces.size()]
	return load(TerrainCatalog.tile_path(terrain_style, filename)) as Texture2D


func _build_obstacle() -> void:
	for child in get_children():
		if child is Sprite2D:
			child.free()

	_piece_size = Vector2(TerrainCatalog.TILE_SIZE)

	for row in pieces_vertical:
		for col in pieces_horizontal:
			var texture := _pick_rock_texture()
			if texture == null:
				continue

			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = true
			sprite.position = Vector2(
				_piece_size.x * (col + 0.5),
				-_piece_size.y * (row + 0.5)
			)
			add_child(sprite)

	var footprint := get_footprint_size()
	var anchor := Vector2(footprint.x * 0.5, -footprint.y * 0.5)

	if collision_shape:
		var rect := RectangleShape2D.new()
		rect.size = footprint * Vector2(0.92, 0.9)
		collision_shape.shape = rect
		collision_shape.position = anchor
