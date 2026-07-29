@tool
class_name TerrainAuthoringManifest
extends Resource

@export_file("*.tres", "*.res") var target_tileset_path := ""
@export_file("*.png") var output_atlas_path := ""
@export_range(0, 4095, 1) var output_source_id := 1
@export_range(1, 1024, 1) var tile_size := 16
@export var terrain_entries: Array[TerrainInputSpec] = []


# 返回 manifest 及全部 Terrain 条目的明确配置错误。
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_tileset_path.is_empty() or not target_tileset_path.begins_with("res://"):
		errors.append("Target TileSet must use a res:// path")
	elif not ResourceLoader.exists(target_tileset_path, "TileSet"):
		errors.append("Target TileSet does not exist: %s" % target_tileset_path)
	if output_atlas_path.is_empty() or not output_atlas_path.begins_with("res://"):
		errors.append("Output atlas must use a res:// path")
	if tile_size <= 0:
		errors.append("Manifest tile size must be positive")
	if terrain_entries.is_empty():
		errors.append("Manifest must contain at least one Terrain entry")
	var terrain_sets := {}
	for entry_index in terrain_entries.size():
		var entry := terrain_entries[entry_index]
		if entry == null:
			errors.append("Terrain entry %d is missing" % entry_index)
			continue
		for entry_error in entry.validate(tile_size):
			errors.append("Terrain entry %d: %s" % [entry_index, entry_error])
		if terrain_sets.has(entry.terrain_set_index):
			errors.append("Terrain Set index %d is duplicated" % entry.terrain_set_index)
		terrain_sets[entry.terrain_set_index] = true
	return errors


# 返回最终生成 atlas 的像素尺寸。
func get_output_pixel_size() -> Vector2i:
	var width_tiles := 0
	var height_tiles := 0
	for entry in terrain_entries:
		if entry == null:
			continue
		var output_size := TerrainConversionCore.get_output_tile_size(StringName(entry.input_format))
		width_tiles = maxi(width_tiles, output_size.x)
		height_tiles += output_size.y
	return Vector2i(tile_size * width_tiles, tile_size * height_tiles)


# 返回一项 Terrain 在共享生成 atlas 中的左上 tile 坐标。
func get_entry_output_origin_tiles(entry_index: int) -> Vector2i:
	var y := 0
	for index in entry_index:
		var entry := terrain_entries[index]
		if entry != null:
			y += TerrainConversionCore.get_output_tile_size(StringName(entry.input_format)).y
	return Vector2i(0, y)
