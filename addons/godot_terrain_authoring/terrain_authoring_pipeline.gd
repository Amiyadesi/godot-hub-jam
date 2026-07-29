@tool
class_name TerrainAuthoringPipeline
extends RefCounted


# 验证 manifest 和全部源图区域，不修改任何资源。
static func validate_manifest(manifest: TerrainAuthoringManifest) -> PackedStringArray:
	var errors := manifest.validate()
	if not errors.is_empty():
		return errors
	for entry_index in manifest.terrain_entries.size():
		var entry := manifest.terrain_entries[entry_index]
		var source_image := Image.load_from_file(ProjectSettings.globalize_path(entry.source_image_path))
		if source_image == null or source_image.is_empty():
			errors.append("Terrain entry %d source image could not be loaded: %s" % [entry_index, entry.source_image_path])
			continue
		var format_size := TerrainConversionCore.get_format_tile_size(StringName(entry.input_format))
		var pixel_region := Rect2i(entry.source_origin_tiles * manifest.tile_size, format_size * manifest.tile_size)
		if not Rect2i(Vector2i.ZERO, source_image.get_size()).encloses(pixel_region):
			errors.append("Terrain entry %d region is outside source image: %s" % [entry_index, pixel_region])
	return errors


# 将 manifest 中各输入按顺序纵向合成为单一生成 atlas。
static func generate_atlas(manifest: TerrainAuthoringManifest) -> Dictionary:
	var errors := validate_manifest(manifest)
	if not errors.is_empty():
		return {"error": "\n".join(errors), "image": null}
	var output_size := manifest.get_output_pixel_size()
	var atlas := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	for entry_index in manifest.terrain_entries.size():
		var entry := manifest.terrain_entries[entry_index]
		var source_image := Image.load_from_file(ProjectSettings.globalize_path(entry.source_image_path))
		var converted := TerrainConversionCore.convert_region(
			source_image,
			StringName(entry.input_format),
			entry.source_origin_tiles,
			manifest.tile_size
		)
		if converted == null:
			return {"error": "Terrain entry %d conversion failed" % entry_index, "image": null}
		atlas.blit_rect(
			converted,
			Rect2i(Vector2i.ZERO, converted.get_size()),
			manifest.get_entry_output_origin_tiles(entry_index) * manifest.tile_size
		)
	return {"error": "", "image": atlas}


# 生成 canonical atlas 并保存到 manifest 指定的 PNG。
static func generate_and_save_atlas(manifest: TerrainAuthoringManifest) -> String:
	var result := generate_atlas(manifest)
	var error: String = result.get("error", "Unknown terrain atlas generation error")
	if not error.is_empty():
		return error
	var output_directory := ProjectSettings.globalize_path(manifest.output_atlas_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		return "Could not create terrain atlas directory: %s" % output_directory
	var atlas := result.get("image") as Image
	var save_error := atlas.save_png(ProjectSettings.globalize_path(manifest.output_atlas_path))
	if save_error != OK:
		return "Could not save terrain atlas %s (error %d)" % [manifest.output_atlas_path, save_error]
	return ""
