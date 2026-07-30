@tool
class_name GodotTerrainBuilder
extends RefCounted

# Godot 4 peering wiring is informed by Blobsmith; see THIRD_PARTY_NOTICES.md.

const SOURCE_MANAGED_META := &"godot_terrain_authoring_managed"
const SOURCE_MANIFEST_META := &"godot_terrain_authoring_manifest"
const SOURCE_TEXTURE_META := &"godot_terrain_authoring_texture"
const TERRAIN_SETS_META := &"godot_terrain_authoring_sets"

const BIT_TO_NEIGHBOR := {
	1: TileSet.CELL_NEIGHBOR_TOP_SIDE,
	2: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	4: TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	8: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	16: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	32: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	64: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	128: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
}


# 将 canonical atlas 安全追加或更新到现有 TileSet。
static func augment_tileset(
		tile_set: TileSet,
		texture: Texture2D,
		manifest: TerrainAuthoringManifest,
		manifest_path: String
	) -> String:
	var error := _validate_inputs(tile_set, texture, manifest, manifest_path)
	if not error.is_empty():
		return error
	error = _validate_source_ownership(tile_set, manifest, manifest_path)
	if not error.is_empty():
		return error
	error = _validate_terrain_set_ownership(tile_set, manifest, manifest_path)
	if not error.is_empty():
		return error
	_configure_terrain_sets(tile_set, manifest, manifest_path)
	if tile_set.has_source(manifest.output_source_id):
		tile_set.remove_source(manifest.output_source_id)
	var source := _create_managed_source(tile_set, texture, manifest, manifest_path)
	_populate_tiles(source, manifest)
	return ""


# 在写入前检查尺寸、物理层和必需资源。
static func _validate_inputs(
		tile_set: TileSet,
		texture: Texture2D,
		manifest: TerrainAuthoringManifest,
		manifest_path: String
	) -> String:
	if tile_set == null:
		return "Target TileSet is missing"
	if texture == null:
		return "Generated terrain atlas texture is missing"
	if manifest == null:
		return "Terrain authoring manifest is missing"
	if manifest_path.is_empty():
		return "Terrain authoring manifest path is missing"
	if tile_set.tile_size != Vector2i(manifest.tile_size, manifest.tile_size):
		return "TileSet tile size %s does not match manifest tile size %d" % [tile_set.tile_size, manifest.tile_size]
	if Vector2i(texture.get_size()) != manifest.get_output_pixel_size():
		return "Generated atlas size %s does not match manifest size %s" % [texture.get_size(), manifest.get_output_pixel_size()]
	if tile_set.get_physics_layers_count() <= 0:
		return "Target TileSet must define physics layer 0 for World collision"
	return ""


# 确保指定 source id 为空或确实由同一 manifest 管理。
static func _validate_source_ownership(
		tile_set: TileSet,
		manifest: TerrainAuthoringManifest,
		manifest_path: String
	) -> String:
	if not tile_set.has_source(manifest.output_source_id):
		return ""
	var source := tile_set.get_source(manifest.output_source_id)
	if not source.get_meta(SOURCE_MANAGED_META, false):
		return "TileSet source id %d is occupied by an unmanaged source" % manifest.output_source_id
	if source.get_meta(SOURCE_MANIFEST_META, "") != manifest_path:
		return "TileSet source id %d belongs to another terrain manifest" % manifest.output_source_id
	if source.get_meta(SOURCE_TEXTURE_META, "") != manifest.output_atlas_path:
		return "TileSet source id %d points to a different managed texture" % manifest.output_source_id
	var atlas_source := source as TileSetAtlasSource
	if atlas_source == null:
		return "TileSet source id %d is not an atlas source" % manifest.output_source_id
	var texture_path := atlas_source.texture.resource_path if atlas_source.texture != null else ""
	if not texture_path.is_empty() and texture_path != manifest.output_atlas_path:
		return "TileSet source id %d texture path does not match the manifest" % manifest.output_source_id
	return ""


# 确保即将更新的 Terrain Set 没有覆盖用户手工数据。
static func _validate_terrain_set_ownership(
		tile_set: TileSet,
		manifest: TerrainAuthoringManifest,
		manifest_path: String
	) -> String:
	var managed_sets: Dictionary = tile_set.get_meta(TERRAIN_SETS_META, {})
	var requested_sets := {}
	for entry in manifest.terrain_entries:
		requested_sets[entry.terrain_set_index] = entry.terrain_name
		if entry.terrain_set_index < tile_set.get_terrain_sets_count():
			var marker: Dictionary = managed_sets.get(str(entry.terrain_set_index), {})
			if marker.get("manifest", "") != manifest_path:
				return "Terrain Set %d is occupied by unmanaged data" % entry.terrain_set_index
	var current_count := tile_set.get_terrain_sets_count()
	var max_index := -1
	for terrain_set_index in requested_sets:
		max_index = maxi(max_index, terrain_set_index)
	for terrain_set_index in range(current_count, max_index + 1):
		if not requested_sets.has(terrain_set_index):
			return "Terrain Set %d would create an unmanaged index gap" % terrain_set_index
	return ""


# 创建或重置 manifest 管理的 Terrain Set，并记录所有权元数据。
static func _configure_terrain_sets(
		tile_set: TileSet,
		manifest: TerrainAuthoringManifest,
		manifest_path: String
	) -> void:
	var max_index := -1
	for entry in manifest.terrain_entries:
		max_index = maxi(max_index, entry.terrain_set_index)
	while tile_set.get_terrain_sets_count() <= max_index:
		tile_set.add_terrain_set()
	var managed_sets: Dictionary = tile_set.get_meta(TERRAIN_SETS_META, {})
	for entry in manifest.terrain_entries:
		var terrain_set_index := entry.terrain_set_index
		var terrain_mode := (
			TileSet.TERRAIN_MODE_MATCH_SIDES
			if entry.input_format == "4x4_sides"
			else TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES
		)
		tile_set.set_terrain_set_mode(terrain_set_index, terrain_mode)
		while tile_set.get_terrains_count(terrain_set_index) > 0:
			tile_set.remove_terrain(terrain_set_index, 0)
		tile_set.add_terrain(terrain_set_index)
		tile_set.set_terrain_name(terrain_set_index, 0, entry.terrain_name)
		tile_set.set_terrain_color(terrain_set_index, 0, Color.from_hsv(float(terrain_set_index % 8) / 8.0, 0.55, 0.8))
		managed_sets[str(terrain_set_index)] = {
			"manifest": manifest_path,
			"name": entry.terrain_name,
		}
	tile_set.set_meta(TERRAIN_SETS_META, managed_sets)


# 创建带明确管理标记的 atlas source。
static func _create_managed_source(
		tile_set: TileSet,
		texture: Texture2D,
		manifest: TerrainAuthoringManifest,
		manifest_path: String
	) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.resource_name = "Godot Terrain Authoring Source %d" % manifest.output_source_id
	source.resource_scene_unique_id = "TerrainAuthoring_%s_%d" % [manifest_path.sha256_text().substr(0, 12), manifest.output_source_id]
	source.texture = texture
	source.texture_region_size = Vector2i(manifest.tile_size, manifest.tile_size)
	source.set_meta(SOURCE_MANAGED_META, true)
	source.set_meta(SOURCE_MANIFEST_META, manifest_path)
	source.set_meta(SOURCE_TEXTURE_META, manifest.output_atlas_path)
	tile_set.add_source(source, manifest.output_source_id)
	return source


# 按每种输入格式写入 Terrain peering bits 与 World collision。
static func _populate_tiles(
		source: TileSetAtlasSource,
		manifest: TerrainAuthoringManifest
	) -> void:
	var masks := TerrainConversionCore.blob47_masks()
	var half := manifest.tile_size / 2.0
	var collision_points := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	for entry_index in manifest.terrain_entries.size():
		var entry := manifest.terrain_entries[entry_index]
		var atlas_origin := manifest.get_entry_output_origin_tiles(entry_index)
		if entry.input_format == "4x4_sides":
			_populate_sides_tiles(source, entry, atlas_origin, collision_points)
			continue
		for mask_index in masks.size():
			var mask := masks[mask_index]
			var atlas_coord := atlas_origin + Vector2i(mask_index % 8, mask_index / 8)
			source.create_tile(atlas_coord)
			var tile_data := source.get_tile_data(atlas_coord, 0)
			tile_data.terrain_set = entry.terrain_set_index
			tile_data.terrain = 0
			for bit in BIT_TO_NEIGHBOR:
				if mask & bit:
					tile_data.set_terrain_peering_bit(BIT_TO_NEIGHBOR[bit], 0)
			if entry.collision_policy == TerrainInputSpec.CollisionPolicy.WORLD:
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, collision_points)


# 将原始 4x4 四边组合转换为 MATCH_SIDES 的四向邻接数据。
static func _populate_sides_tiles(
		source: TileSetAtlasSource,
		entry: TerrainInputSpec,
		atlas_origin: Vector2i,
		collision_points: PackedVector2Array
	) -> void:
	for y in 4:
		for x in 4:
			var atlas_coord := atlas_origin + Vector2i(x, y)
			source.create_tile(atlas_coord)
			var tile_data := source.get_tile_data(atlas_coord, 0)
			tile_data.terrain_set = entry.terrain_set_index
			tile_data.terrain = 0
			if y in [1, 2]:
				tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, 0)
			if x in [0, 1]:
				tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 0)
			if y in [0, 1]:
				tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 0)
			if x in [1, 2]:
				tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, 0)
			if entry.collision_policy == TerrainInputSpec.CollisionPolicy.WORLD:
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, collision_points)
