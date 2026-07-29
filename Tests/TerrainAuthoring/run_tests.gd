extends SceneTree

const CONVERSION_CORE := preload("res://addons/godot_terrain_authoring/terrain_conversion_core.gd")
const INPUT_SPEC_SCRIPT := preload("res://addons/godot_terrain_authoring/terrain_input_spec.gd")
const MANIFEST_SCRIPT := preload("res://addons/godot_terrain_authoring/terrain_authoring_manifest.gd")
const TERRAIN_BUILDER := preload("res://addons/godot_terrain_authoring/godot_terrain_builder.gd")
const GOLDEN_TILE_SIZE := 4
const PROJECT_TILESET_PATH := "res://assets/echo_chase/tilemap/echo_platform_tileset.tres"
const WEBTYLER_GOLDEN_MASKS := [
	16, 20, 84, 80, 213, 92, 116, 87, 28, 125, 124, 112,
	17, 21, 85, 81, 29, 127, 253, 113, 31, 119, -1, 245,
	1, 5, 69, 65, 23, 223, 247, 209, 95, 255, 221, 241,
	0, 4, 68, 64, 117, 71, 197, 93, 7, 199, 215, 193,
]
const MASK_NEIGHBOR_OFFSETS := {
	1: Vector2i(0, -1),
	2: Vector2i(1, -1),
	4: Vector2i(1, 0),
	8: Vector2i(1, 1),
	16: Vector2i(0, 1),
	32: Vector2i(-1, 1),
	64: Vector2i(-1, 0),
	128: Vector2i(-1, -1),
}
const PROJECT_TERRAIN_NAMES := [
	"Panel A Clean",
	"Panel A Worn",
	"Panel B Clean",
	"Panel B Worn",
	"Panel C Clean",
	"Panel C Worn",
]
const PROJECT_TERRAIN_ORIGINS := [
	Vector2i(10, 5),
	Vector2i(15, 5),
	Vector2i(10, 9),
	Vector2i(15, 9),
	Vector2i(10, 13),
	Vector2i(15, 13),
]

var _failures: Array[String] = []


# 运行 Terrain Authoring 的公开行为测试。
func _init() -> void:
	_test_canonical_blob_masks()
	_test_4x4_conversion_matches_webtyler_layout()
	_test_4x4_sides_copies_source_without_reordering()
	_test_all_formats_match_webtyler_golden_pixels()
	_test_invalid_manifest_and_atlas_fail_loudly()
	_test_tileset_augmentation_is_safe_and_idempotent()
	_test_sides_tileset_uses_four_way_peering()
	_test_unmanaged_source_conflict_fails_without_overwrite()
	_test_unmanaged_terrain_set_conflict_fails_without_overwrite()
	_test_project_tileset_contract_and_terrain_shapes()
	_finish()


# 验证 canonical blob 只有 47 个升序且满足角落约束的 mask。
func _test_canonical_blob_masks() -> void:
	var masks: Array[int] = CONVERSION_CORE.blob47_masks()
	_expect(masks.size() == 47, "Canonical blob contains 47 masks")
	var sorted_masks := masks.duplicate()
	sorted_masks.sort()
	_expect(masks == sorted_masks, "Canonical masks are ascending")
	var unique_masks := {}
	for mask in masks:
		unique_masks[mask] = true
		_expect(CONVERSION_CORE.canonical_mask(mask) == mask, "Mask %d obeys corner constraints" % mask)
	_expect(unique_masks.size() == 47, "Canonical masks are unique")


# 验证 4x4 输入先遵循 Webtyler 的 Godot 布局，再重排为 canonical 8x6。
func _test_4x4_conversion_matches_webtyler_layout() -> void:
	var tile_size := 4
	var source := Image.create(tile_size * 4, tile_size * 4, false, Image.FORMAT_RGBA8)
	for source_index in 16:
		var source_coord := Vector2i(source_index % 4, source_index / 4)
		var color := Color8(source_index + 1, 0, 0, 255)
		source.fill_rect(Rect2i(source_coord * tile_size, Vector2i(tile_size, tile_size)), color)
	var output: Image = CONVERSION_CORE.convert_region(source, &"4x4", Vector2i.ZERO, tile_size)
	_expect(output != null, "4x4 conversion returns an image")
	if output == null:
		return
	_expect(output.get_size() == Vector2i(tile_size * 8, tile_size * 6), "Canonical output uses an 8x6 atlas")
	var expected_source_indices := PackedInt32Array([
		12, 8, 13, 9, 9, 0, 4, 1,
		5, 5, 1, 5, 5, 15, 11, 14,
		10, 10, 3, 7, 2, 6, 6, 2,
		6, 6, 3, 7, 2, 6, 6, 2,
		6, 6, 11, 10, 10, 7, 6, 6,
		6, 6, 7, 6, 6, 6, 6,
	])
	for output_index in expected_source_indices.size():
		var pixel := output.get_pixel((output_index % 8) * tile_size, (output_index / 8) * tile_size)
		_expect(
			int(round(pixel.r * 255.0)) == expected_source_indices[output_index] + 1,
			"Canonical tile %d comes from Webtyler source tile %d" % [output_index, expected_source_indices[output_index]]
		)
	_expect(output.get_pixel(tile_size * 7, tile_size * 5).a == 0.0, "Canonical atlas leaves the final cell empty")


# 验证四边组合输入保持原始十六格顺序，不走 Webtyler 扩展。
func _test_4x4_sides_copies_source_without_reordering() -> void:
	var tile_size := 4
	var source := Image.create(tile_size * 4, tile_size * 4, false, Image.FORMAT_RGBA8)
	for source_index in 16:
		var source_coord := Vector2i(source_index % 4, source_index / 4)
		source.fill_rect(
			Rect2i(source_coord * tile_size, Vector2i(tile_size, tile_size)),
			Color8(source_index + 1, source_index + 2, source_index + 3, 255)
		)
	var output: Image = CONVERSION_CORE.convert_region(source, &"4x4_sides", Vector2i.ZERO, tile_size)
	_expect(output != null, "4x4_sides conversion returns an image")
	if output == null:
		return
	_expect(output.get_size() == Vector2i(tile_size * 4, tile_size * 4), "4x4_sides output keeps a 4x4 atlas")
	_expect(output.get_data() == source.get_data(), "4x4_sides preserves all source pixels and tile order")


# 验证全部 13 种输入逐像素匹配固定 Webtyler commit 生成的 golden 输出。
func _test_all_formats_match_webtyler_golden_pixels() -> void:
	for input_format in CONVERSION_CORE.supported_formats():
		if input_format == "4x4_sides":
			continue
		var input_size: Vector2i = CONVERSION_CORE.get_format_tile_size(input_format)
		var source := _create_pattern_image(input_size * GOLDEN_TILE_SIZE)
		var actual: Image = CONVERSION_CORE.convert_region(source, input_format, Vector2i.ZERO, GOLDEN_TILE_SIZE)
		var fixture_path := "res://Tests/TerrainAuthoring/fixtures/webtyler_%s.png" % input_format
		var fixture_texture := load(fixture_path) as Texture2D
		var webtyler_golden := fixture_texture.get_image() if fixture_texture != null else null
		_expect(webtyler_golden != null, "%s Webtyler golden fixture loads" % input_format)
		if actual == null or webtyler_golden == null:
			continue
		var expected := _canonical_from_webtyler_golden(webtyler_golden)
		_expect(
			actual.get_data() == expected.get_data(),
			"%s conversion matches Webtyler golden pixels" % input_format
		)


# 创建与 golden fixture 生成器相同的确定性像素输入。
func _create_pattern_image(pixel_size: Vector2i) -> Image:
	var image := Image.create(pixel_size.x, pixel_size.y, false, Image.FORMAT_RGBA8)
	for y in pixel_size.y:
		for x in pixel_size.x:
			image.set_pixel(
				x,
				y,
				Color8(
					(x * 17 + y * 3 + 1) % 256,
					(x * 5 + y * 31 + 2) % 256,
					(x * 11 + y * 13 + 3) % 256,
					255
				)
			)
	return image


# 独立按 mask 将上游 12x4 golden atlas 重排为 canonical 8x6。
func _canonical_from_webtyler_golden(webtyler_golden: Image) -> Image:
	var expected := Image.create(GOLDEN_TILE_SIZE * 8, GOLDEN_TILE_SIZE * 6, false, Image.FORMAT_RGBA8)
	var source_by_mask := {}
	for source_index in WEBTYLER_GOLDEN_MASKS.size():
		var mask: int = WEBTYLER_GOLDEN_MASKS[source_index]
		if mask >= 0:
			source_by_mask[mask] = Vector2i(source_index % 12, source_index / 12)
	var masks: Array[int] = CONVERSION_CORE.blob47_masks()
	for output_index in masks.size():
		var source_tile: Vector2i = source_by_mask[masks[output_index]]
		expected.blit_rect(
			webtyler_golden,
			Rect2i(source_tile * GOLDEN_TILE_SIZE, Vector2i(GOLDEN_TILE_SIZE, GOLDEN_TILE_SIZE)),
			Vector2i(output_index % 8, output_index / 8) * GOLDEN_TILE_SIZE
		)
	return expected


# 验证未知格式、重复索引和错误 atlas 尺寸都返回明确错误。
func _test_invalid_manifest_and_atlas_fail_loudly() -> void:
	var manifest := _create_test_manifest()
	var duplicate_entry := INPUT_SPEC_SCRIPT.new()
	duplicate_entry.terrain_name = "Duplicate"
	duplicate_entry.input_format = "unknown"
	duplicate_entry.source_image_path = "res://Tests/TerrainAuthoring/fixtures/webtyler_4x4.png"
	duplicate_entry.terrain_set_index = 0
	manifest.terrain_entries.append(duplicate_entry)
	var validation_errors := "\n".join(manifest.validate())
	_expect(validation_errors.contains("Unknown terrain input format"), "Unknown input format fails manifest validation")
	_expect(validation_errors.contains("Terrain Set index 0 is duplicated"), "Duplicate Terrain Set index fails manifest validation")
	manifest.terrain_entries.resize(1)
	var tile_set := _create_test_tileset()
	var wrong_size_texture := ImageTexture.create_from_image(Image.create(31, 24, false, Image.FORMAT_RGBA8))
	var build_error := TERRAIN_BUILDER.augment_tileset(tile_set, wrong_size_texture, manifest, "res://test_manifest.tres")
	_expect(build_error.contains("atlas size"), "Wrong generated atlas size fails before TileSet mutation")


# 验证 builder 只追加受管 source，并保留 source 0 与 Trap 数据。
func _test_tileset_augmentation_is_safe_and_idempotent() -> void:
	var tile_set := _create_test_tileset()
	var source_zero := tile_set.get_source(0)
	var source_zero_snapshot := _snapshot_atlas_source(source_zero as TileSetAtlasSource, tile_set.get_physics_layers_count())
	var physics_snapshot := _snapshot_physics_layers(tile_set)
	var trap_tile := (source_zero as TileSetAtlasSource).get_tile_data(Vector2i.ZERO, 0)
	var trap_points := trap_tile.get_collision_polygon_points(1, 0)
	var manifest := _create_test_manifest()
	var texture := ImageTexture.create_from_image(Image.create(32, 24, false, Image.FORMAT_RGBA8))
	var error := TERRAIN_BUILDER.augment_tileset(tile_set, texture, manifest, "res://test_manifest.tres")
	_expect(error == "", "Managed terrain source augments an existing TileSet")
	if error != "":
		return
	_expect(tile_set.get_source(0) == source_zero, "Source 0 object is preserved")
	_expect(tile_set.get_source_count() == 2 and tile_set.has_source(1), "Managed source uses requested source id 1")
	_expect(tile_set.get_terrain_sets_count() == 1, "Builder creates the requested Terrain Set")
	_expect(tile_set.get_terrains_count(0) == 1, "Terrain Set contains one Terrain")
	_expect(tile_set.get_terrain_name(0, 0) == "Test Terrain", "Terrain keeps the authored name")
	_expect(tile_set.get_physics_layers_count() == 2, "Builder preserves World and Trap physics layers")
	_expect(tile_set.get_physics_layer_collision_layer(1) == 32, "Trap collision layer remains unchanged")
	_expect(trap_tile.get_collision_polygon_points(1, 0) == trap_points, "Existing Trap polygon remains unchanged")
	_expect(
		_snapshot_atlas_source(tile_set.get_source(0) as TileSetAtlasSource, tile_set.get_physics_layers_count()) == source_zero_snapshot,
		"Source 0 semantic data remains unchanged"
	)
	_expect(_snapshot_physics_layers(tile_set) == physics_snapshot, "TileSet physics layer settings remain unchanged")
	var managed_source := tile_set.get_source(1) as TileSetAtlasSource
	_expect(managed_source.get_tiles_count() == 47, "Managed source creates 47 non-empty tiles")
	_expect(managed_source.resource_scene_unique_id == "TerrainAuthoring_%s_1" % "res://test_manifest.tres".sha256_text().substr(0, 12), "Managed source uses a deterministic subresource id")
	for tile_index in managed_source.get_tiles_count():
		var atlas_coord := managed_source.get_tile_id(tile_index)
		var tile_data := managed_source.get_tile_data(atlas_coord, 0)
		_expect(tile_data.terrain_set == 0 and tile_data.terrain == 0, "Managed tile %s belongs to Terrain 0" % atlas_coord)
		_expect(tile_data.get_collision_polygons_count(0) == 1, "Managed tile %s has World collision" % atlas_coord)
		_expect(tile_data.get_collision_polygons_count(1) == 0, "Managed tile %s has no Trap collision" % atlas_coord)
	var source_count := tile_set.get_source_count()
	error = TERRAIN_BUILDER.augment_tileset(tile_set, texture, manifest, "res://test_manifest.tres")
	_expect(error == "", "Repeating a managed augmentation succeeds")
	_expect(tile_set.get_source_count() == source_count, "Repeated augmentation does not duplicate sources")
	_expect((tile_set.get_source(1) as TileSetAtlasSource).get_tiles_count() == 47, "Repeated augmentation remains at 47 tiles")
	_expect((tile_set.get_source(1) as TileSetAtlasSource).resource_scene_unique_id == managed_source.resource_scene_unique_id, "Repeated augmentation keeps the managed subresource id")
	var save_path := "user://terrain_authoring_builder_test.tres"
	var save_error := ResourceSaver.save(tile_set, save_path)
	_expect(save_error == OK, "Augmented TileSet saves successfully")
	if save_error == OK:
		var reloaded := ResourceLoader.load(save_path, "TileSet", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
		_expect(reloaded != null, "Augmented TileSet reloads successfully")
		if reloaded != null:
			_expect(
				_snapshot_atlas_source(reloaded.get_source(0) as TileSetAtlasSource, reloaded.get_physics_layers_count()) == source_zero_snapshot,
				"Source 0 survives TileSet save and reload"
			)
			_expect(_snapshot_physics_layers(reloaded) == physics_snapshot, "Physics layers survive TileSet save and reload")
			_expect((reloaded.get_source(1) as TileSetAtlasSource).get_tiles_count() == 47, "Managed source survives TileSet save and reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# 验证四边组合只创建十六格，并使用四向 Terrain 邻接。
func _test_sides_tileset_uses_four_way_peering() -> void:
	var tile_set := _create_test_tileset()
	var manifest := _create_sides_test_manifest()
	_expect(manifest.get_output_pixel_size() == Vector2i(16, 16), "4x4_sides manifest keeps a 4x4 output atlas")
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var error := TERRAIN_BUILDER.augment_tileset(tile_set, texture, manifest, "res://test_sides_manifest.tres")
	_expect(error == "", "4x4_sides augments an existing TileSet")
	if not error.is_empty():
		return
	_expect(tile_set.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_SIDES, "4x4_sides uses MATCH_SIDES")
	var source := tile_set.get_source(1) as TileSetAtlasSource
	_expect(source.get_tiles_count() == 16, "4x4_sides creates exactly sixteen tiles")
	for y in 4:
		for x in 4:
			var atlas_coord := Vector2i(x, y)
			var tile_data := source.get_tile_data(atlas_coord, 0)
			_expect(tile_data != null, "4x4_sides creates tile %s" % atlas_coord)
			if tile_data == null:
				continue
			_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == (0 if y in [1, 2] else -1), "Tile %s top edge matches source border" % atlas_coord)
			_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == (0 if x in [0, 1] else -1), "Tile %s right edge matches source border" % atlas_coord)
			_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == (0 if y in [0, 1] else -1), "Tile %s bottom edge matches source border" % atlas_coord)
			_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == (0 if x in [1, 2] else -1), "Tile %s left edge matches source border" % atlas_coord)
			_expect(tile_data.get_collision_polygons_count(0) == 1, "Tile %s keeps World collision" % atlas_coord)
			_expect(tile_data.get_collision_polygons_count(1) == 0, "Tile %s has no Trap collision" % atlas_coord)


# 验证 source id 已被其他资源占用时直接失败且不覆盖。
func _test_unmanaged_source_conflict_fails_without_overwrite() -> void:
	var tile_set := _create_test_tileset()
	var conflicting_source := TileSetAtlasSource.new()
	conflicting_source.texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	conflicting_source.texture_region_size = Vector2i(4, 4)
	tile_set.add_source(conflicting_source, 1)
	var manifest := _create_test_manifest()
	var texture := ImageTexture.create_from_image(Image.create(32, 24, false, Image.FORMAT_RGBA8))
	var error := TERRAIN_BUILDER.augment_tileset(tile_set, texture, manifest, "res://test_manifest.tres")
	_expect(error.contains("source id 1"), "Unmanaged source conflict reports the occupied id")
	_expect(tile_set.get_source(1) == conflicting_source, "Unmanaged source remains untouched after conflict")


# 验证未受管 Terrain Set 不会被 manifest 覆盖。
func _test_unmanaged_terrain_set_conflict_fails_without_overwrite() -> void:
	var tile_set := _create_test_tileset()
	tile_set.add_terrain_set(0)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "User Terrain")
	var manifest := _create_test_manifest()
	var texture := ImageTexture.create_from_image(Image.create(32, 24, false, Image.FORMAT_RGBA8))
	var error := TERRAIN_BUILDER.augment_tileset(tile_set, texture, manifest, "res://test_manifest.tres")
	_expect(error.contains("Terrain Set 0 is occupied by unmanaged data"), "Unmanaged Terrain Set conflict reports the occupied index")
	_expect(tile_set.get_terrain_name(0, 0) == "User Terrain", "Unmanaged Terrain Set remains untouched after conflict")
	_expect(not tile_set.has_source(1), "Terrain Set conflict does not create the managed source")


# 验证项目 TileSet 的六组 Terrain、peering bits、碰撞层和常见绘制形状。
func _test_project_tileset_contract_and_terrain_shapes() -> void:
	var tile_set := load(PROJECT_TILESET_PATH) as TileSet
	_expect(tile_set != null, "Project Terrain TileSet reloads from disk")
	if tile_set == null:
		return
	_expect(tile_set.get_physics_layers_count() == 2, "Project TileSet keeps World and Trap physics layers")
	_expect(tile_set.get_physics_layer_collision_layer(0) == 1, "Project World layer keeps collision bit 1")
	_expect(tile_set.get_physics_layer_collision_layer(1) == 32, "Project Trap layer keeps collision bit 32")
	_expect(tile_set.has_source(0), "Project TileSet keeps source 0")
	_expect(tile_set.has_source(1), "Project TileSet contains managed source 1")
	var source_zero := tile_set.get_source(0) as TileSetAtlasSource
	var managed_source := tile_set.get_source(1) as TileSetAtlasSource
	_expect(source_zero != null, "Project source 0 remains an atlas source")
	_expect(managed_source != null, "Project source 1 is an atlas source")
	if source_zero == null or managed_source == null:
		return
	_expect(source_zero.texture.resource_path == "res://assets/echo_chase/tilemap/monochrome_tilemap_transparent_packed.png", "Project source 0 keeps its authored texture")
	_expect(managed_source.texture.resource_path == "res://assets/echo_chase/tilemap/generated/echo_platform_terrain_47.png", "Managed source uses the generated atlas")
	_expect(Vector2i(managed_source.texture.get_size()) == Vector2i(64, 384), "Managed project atlas is 64 by 384 pixels")
	_expect(managed_source.get_meta(TERRAIN_BUILDER.SOURCE_MANAGED_META, false), "Managed source keeps its ownership marker")
	_expect(managed_source.get_meta(TERRAIN_BUILDER.SOURCE_MANIFEST_META, "") == "res://assets/echo_chase/tilemap/echo_platform_terrain_manifest.tres", "Managed source keeps its manifest marker")
	for trap_coord in [Vector2i(6, 0), Vector2i(6, 8), Vector2i(3, 9)]:
		var trap_data := source_zero.get_tile_data(trap_coord, 0)
		_expect(trap_data != null, "Existing Trap tile %s remains present" % trap_coord)
		if trap_data != null:
			_expect(trap_data.get_collision_polygons_count(1) == 1, "Existing Trap tile %s keeps its Trap polygon" % trap_coord)
	_expect(managed_source.get_tiles_count() == 96, "Managed source contains six raw 4x4 terrain groups")
	_expect(tile_set.get_terrain_sets_count() == PROJECT_TERRAIN_NAMES.size(), "Project TileSet contains six Terrain Sets")
	var source_image := source_zero.texture.get_image()
	var generated_image := managed_source.texture.get_image()
	for terrain_set_index in PROJECT_TERRAIN_NAMES.size():
		_expect(tile_set.get_terrain_set_mode(terrain_set_index) == TileSet.TERRAIN_MODE_MATCH_SIDES, "Terrain Set %d uses side matching" % terrain_set_index)
		_expect(tile_set.get_terrains_count(terrain_set_index) == 1, "Terrain Set %d contains one Terrain" % terrain_set_index)
		_expect(tile_set.get_terrain_name(terrain_set_index, 0) == PROJECT_TERRAIN_NAMES[terrain_set_index], "Terrain Set %d keeps its authored name" % terrain_set_index)
		for y in 4:
			for x in 4:
				var atlas_coord := Vector2i(x, terrain_set_index * 4 + y)
				_expect(managed_source.has_tile(atlas_coord), "Terrain Set %d contains side tile %s" % [terrain_set_index, atlas_coord])
				var tile_data := managed_source.get_tile_data(atlas_coord, 0)
				_expect(tile_data.terrain_set == terrain_set_index and tile_data.terrain == 0, "Side tile %s targets Terrain Set %d" % [atlas_coord, terrain_set_index])
				_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == (0 if y in [1, 2] else -1), "Side tile %s top peering is correct" % atlas_coord)
				_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == (0 if x in [0, 1] else -1), "Side tile %s right peering is correct" % atlas_coord)
				_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == (0 if y in [0, 1] else -1), "Side tile %s bottom peering is correct" % atlas_coord)
				_expect(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == (0 if x in [1, 2] else -1), "Side tile %s left peering is correct" % atlas_coord)
				_expect(tile_data.get_collision_polygons_count(0) == 1, "Side tile %s has World collision" % atlas_coord)
				_expect(tile_data.get_collision_polygons_count(1) == 0, "Side tile %s has no Trap collision" % atlas_coord)
				var source_region := source_image.get_region(Rect2i((PROJECT_TERRAIN_ORIGINS[terrain_set_index] + Vector2i(x, y)) * 16, Vector2i(16, 16)))
				var generated_region := generated_image.get_region(Rect2i(atlas_coord * 16, Vector2i(16, 16)))
				_expect(source_region.get_data() == generated_region.get_data(), "Side tile %s preserves its original pixels" % atlas_coord)
	_test_terrain_connect_shapes(tile_set)


# 使用六个 Terrain Set 分别绘制孤岛、横梁、矩形、L形、凹角和带洞闭环。
func _test_terrain_connect_shapes(tile_set: TileSet) -> void:
	var shapes: Array[Array] = [
		[Vector2i(0, 0)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
		_create_ring_shape(),
	]
	var shape_names := ["island", "horizontal beam", "solid rectangle", "L shape", "concave corner", "ring with hole"]
	for terrain_set_index in shapes.size():
		var cells: Array[Vector2i] = []
		cells.assign(shapes[terrain_set_index])
		var layer := TileMapLayer.new()
		layer.tile_set = tile_set
		layer.set_cells_terrain_connect(cells, terrain_set_index, 0)
		var occupied := {}
		for cell in cells:
			occupied[cell] = true
		for cell in cells:
			var expected_coord := _sides_atlas_coord_for_cell(cell, occupied, terrain_set_index)
			_expect(layer.get_cell_source_id(cell) == 1, "%s draws cell %s from managed source" % [shape_names[terrain_set_index], cell])
			_expect(layer.get_cell_atlas_coords(cell) == expected_coord, "%s selects canonical tile %s at %s" % [shape_names[terrain_set_index], expected_coord, cell])
		layer.free()


# 创建中心留空的五乘五闭环。
func _create_ring_shape() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in 5:
		for x in 5:
			if x == 0 or x == 4 or y == 0 or y == 4:
				cells.append(Vector2i(x, y))
	return cells


# 根据四个正交邻居选择原始 4x4 四边组合中的目标图块。
func _sides_atlas_coord_for_cell(cell: Vector2i, occupied: Dictionary, terrain_set_index: int) -> Vector2i:
	var has_left := occupied.has(cell + Vector2i.LEFT)
	var has_right := occupied.has(cell + Vector2i.RIGHT)
	var has_top := occupied.has(cell + Vector2i.UP)
	var has_bottom := occupied.has(cell + Vector2i.DOWN)
	var source_x := 1 if has_left and has_right else 2 if has_left else 0 if has_right else 3
	var source_y := 1 if has_top and has_bottom else 2 if has_top else 0 if has_bottom else 3
	return Vector2i(source_x, terrain_set_index * 4 + source_y)


# 捕获 atlas source 的 tile、Terrain 与碰撞语义，忽略对象身份和序列化顺序。
func _snapshot_atlas_source(source: TileSetAtlasSource, physics_layer_count: int) -> Array[String]:
	var records: Array[String] = []
	for tile_index in source.get_tiles_count():
		var atlas_coord := source.get_tile_id(tile_index)
		for alternative_index in source.get_alternative_tiles_count(atlas_coord):
			var alternative_id := source.get_alternative_tile_id(atlas_coord, alternative_index)
			var tile_data := source.get_tile_data(atlas_coord, alternative_id)
			var collisions: Array[String] = []
			for physics_layer in physics_layer_count:
				for polygon_index in tile_data.get_collision_polygons_count(physics_layer):
					collisions.append("%d:%s" % [physics_layer, tile_data.get_collision_polygon_points(physics_layer, polygon_index)])
			records.append("%s|%s|%d|%d|%d|%s" % [atlas_coord, source.get_tile_size_in_atlas(atlas_coord), alternative_id, tile_data.terrain_set, tile_data.terrain, collisions])
	records.sort()
	return records


# 捕获 TileSet 物理层的碰撞位配置。
func _snapshot_physics_layers(tile_set: TileSet) -> Array[String]:
	var records: Array[String] = []
	for layer_index in tile_set.get_physics_layers_count():
		records.append("%d:%d" % [tile_set.get_physics_layer_collision_layer(layer_index), tile_set.get_physics_layer_collision_mask(layer_index)])
	return records


# 创建同时含 World 与 Trap 的最小 TileSet fixture。
func _create_test_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(4, 4)
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.add_physics_layer(1)
	tile_set.set_physics_layer_collision_layer(1, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(4, 4)
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.add_collision_polygon(1)
	tile_data.set_collision_polygon_points(1, 0, PackedVector2Array([
		Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2),
	]))
	return tile_set


# 创建只含一个 Terrain 的 manifest fixture。
func _create_test_manifest() -> Resource:
	var input_spec := INPUT_SPEC_SCRIPT.new()
	input_spec.terrain_name = "Test Terrain"
	input_spec.input_format = &"4x4"
	input_spec.source_image_path = "res://Tests/TerrainAuthoring/fixtures/webtyler_4x4.png"
	input_spec.source_origin_tiles = Vector2i.ZERO
	input_spec.terrain_set_index = 0
	input_spec.collision_policy = INPUT_SPEC_SCRIPT.CollisionPolicy.WORLD
	var manifest := MANIFEST_SCRIPT.new()
	manifest.target_tileset_path = "res://test_tileset.tres"
	manifest.output_atlas_path = "res://test_atlas.png"
	manifest.output_source_id = 1
	manifest.tile_size = 4
	manifest.terrain_entries = [input_spec]
	return manifest


# 创建一组原始四边组合 Terrain fixture。
func _create_sides_test_manifest() -> Resource:
	var manifest := _create_test_manifest()
	manifest.output_atlas_path = "res://test_sides_atlas.png"
	manifest.terrain_entries[0].input_format = &"4x4_sides"
	return manifest


# 记录单条断言结果。
func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


# 根据失败数结束测试进程。
func _finish() -> void:
	if _failures.is_empty():
		print("TERRAIN AUTHORING TESTS: ALL PASS")
		quit(0)
		return
	print("TERRAIN AUTHORING TESTS: %d FAILED" % _failures.size())
	quit(1)
