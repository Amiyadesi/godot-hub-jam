@tool
class_name TerrainInputSpec
extends Resource

enum CollisionPolicy {
	NONE,
	WORLD,
}

@export var terrain_name := "Terrain"
@export_enum("basic", "basicborder", "basicfullborder", "basiclongborder", "minitiles", "4x4", "4x4_sides", "4x4plus", "3x3", "3x3plus", "5x3", "5x2", "4x2", "rpgmaker") var input_format := "4x4"
@export_file("*.png") var source_image_path := ""
@export var source_origin_tiles := Vector2i.ZERO
@export_range(0, 255, 1) var terrain_set_index := 0
@export var collision_policy := CollisionPolicy.WORLD


# 返回当前输入条目的明确配置错误。
func validate(tile_size: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if terrain_name.strip_edges().is_empty():
		errors.append("Terrain name must not be empty")
	var format_size := TerrainConversionCore.get_format_tile_size(StringName(input_format))
	if format_size == Vector2i.ZERO:
		errors.append("Unknown terrain input format: %s" % input_format)
	if source_image_path.is_empty() or not source_image_path.begins_with("res://"):
		errors.append("Terrain source image must use a res:// path")
	elif not FileAccess.file_exists(source_image_path):
		errors.append("Terrain source image does not exist: %s" % source_image_path)
	if source_origin_tiles.x < 0 or source_origin_tiles.y < 0:
		errors.append("Terrain source origin must not be negative")
	if tile_size <= 0:
		errors.append("Terrain tile size must be positive")
	return errors
