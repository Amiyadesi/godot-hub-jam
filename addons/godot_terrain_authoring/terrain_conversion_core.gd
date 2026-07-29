@tool
class_name TerrainConversionCore
extends RefCounted

# Modified GDScript port of Webtyler's format conversions; see THIRD_PARTY_NOTICES.md.

const CANONICAL_COLUMNS := 8
const CANONICAL_ROWS := 6
const SIDES_COLUMNS := 4
const SIDES_ROWS := 4
const WEBTYLER_COLUMNS := 12
const WEBTYLER_ROWS := 4

# Webtyler 的 Godot 3 minimal 3x3 atlas，按行记录每格对应的 8-neighbor mask。
const WEBTYLER_MASKS := [
	16, 20, 84, 80, 213, 92, 116, 87, 28, 125, 124, 112,
	17, 21, 85, 81, 29, 127, 253, 113, 31, 119, -1, 245,
	1, 5, 69, 65, 23, 223, 247, 209, 95, 255, 221, 241,
	0, 4, 68, 64, 117, 71, 197, 93, 7, 199, 215, 193,
]

# Webtyler 的 4x4 转换表，值为源图 4x4 中的线性 tile index。
const FOUR_BY_FOUR_SOURCES := [
	0, 1, 2, 3, 6, 2, 2, 6, 1, 6, 2, 3,
	4, 5, 6, 7, 5, 6, 6, 7, 5, 6, -1, 6,
	8, 9, 10, 11, 5, 6, 6, 7, 6, 6, 6, 7,
	12, 13, 14, 15, 6, 10, 10, 6, 9, 10, 6, 11,
]

# Webtyler 的 3x3 quadrant 转换表，每九项描述一格 4x4 中间 tile。
const THREE_BY_THREE_SECTION_SOURCES := [
	0, 2, 2, 3, 5, 5, 3, 5, 5,
	0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 1, 1, 1, 1, 1, 1, 1, 1,
	2, 2, 2, 2, 2, 2, 2, 2, 2,
	3, 5, 5, 3, 5, 5, 3, 5, 5,
	3, 3, 3, 3, 3, 3, 3, 3, 3,
	4, 4, 4, 4, 4, 4, 4, 4, 4,
	5, 5, 5, 5, 5, 5, 5, 5, 5,
	3, 5, 5, 6, 8, 8, 6, 8, 8,
	6, 6, 6, 6, 6, 6, 6, 6, 6,
	7, 7, 7, 7, 7, 7, 7, 7, 7,
	8, 8, 8, 8, 8, 8, 8, 8, 8,
	0, 2, 2, 6, 8, 8, 6, 8, 8,
	0, 0, 0, 6, 6, 6, 6, 6, 6,
	1, 1, 1, 7, 7, 7, 7, 7, 7,
	2, 2, 2, 8, 8, 8, 8, 8, 8,
]

const FORMAT_TILE_SIZES := {
	&"basic": Vector2i(2, 1),
	&"basicborder": Vector2i(2, 1),
	&"basicfullborder": Vector2i(3, 1),
	&"basiclongborder": Vector2i(2, 1),
	&"minitiles": Vector2i(5, 1),
	&"4x4": Vector2i(4, 4),
	&"4x4_sides": Vector2i(4, 4),
	&"4x4plus": Vector2i(5, 4),
	&"3x3": Vector2i(3, 3),
	&"3x3plus": Vector2i(4, 3),
	&"5x3": Vector2i(5, 3),
	&"5x2": Vector2i(5, 2),
	&"4x2": Vector2i(4, 2),
	&"rpgmaker": Vector2i(2, 3),
}


# 将任意 8-neighbor mask 收敛到 corner 仅在两侧同时存在的 canonical mask。
static func canonical_mask(mask: int) -> int:
	var result := mask & 0b01010101
	if mask & 2 and mask & 1 and mask & 4:
		result |= 2
	if mask & 8 and mask & 16 and mask & 4:
		result |= 8
	if mask & 32 and mask & 16 and mask & 64:
		result |= 32
	if mask & 128 and mask & 1 and mask & 64:
		result |= 128
	return result


# 返回升序排列的 47 个 canonical blob mask。
static func blob47_masks() -> Array[int]:
	var seen := {}
	for mask in 256:
		seen[canonical_mask(mask)] = true
	var masks: Array[int] = []
	masks.assign(seen.keys())
	masks.sort()
	return masks


# 返回工具支持的 Webtyler 输入格式。
static func supported_formats() -> PackedStringArray:
	return PackedStringArray(FORMAT_TILE_SIZES.keys())


# 返回一种输入格式占用的 tile 区域尺寸。
static func get_format_tile_size(input_format: StringName) -> Vector2i:
	return FORMAT_TILE_SIZES.get(input_format, Vector2i.ZERO)


# 返回一种输入格式写入生成 atlas 后占用的 tile 尺寸。
static func get_output_tile_size(input_format: StringName) -> Vector2i:
	if input_format == &"4x4_sides":
		return Vector2i(SIDES_COLUMNS, SIDES_ROWS)
	return Vector2i(CANONICAL_COLUMNS, CANONICAL_ROWS)


# 将源图中的一种 Webtyler 输入区域转换为 canonical 47-blob atlas。
static func convert_region(
		source_image: Image,
		input_format: StringName,
		tile_origin: Vector2i,
		tile_size: int
	) -> Image:
	if source_image == null:
		push_error("Terrain conversion source image is missing")
		return null
	if tile_size <= 0:
		push_error("Terrain conversion tile size must be positive")
		return null
	var format_size := get_format_tile_size(input_format)
	if format_size == Vector2i.ZERO:
		push_error("Unknown terrain input format: %s" % input_format)
		return null
	var pixel_region := Rect2i(tile_origin * tile_size, format_size * tile_size)
	if not Rect2i(Vector2i.ZERO, source_image.get_size()).encloses(pixel_region):
		push_error("Terrain input region is outside the source image: %s" % pixel_region)
		return null
	var region := source_image.get_region(pixel_region)
	if input_format == &"4x4_sides":
		return region
	var webtyler_atlas := _convert_to_webtyler_atlas(region, input_format, tile_size)
	if webtyler_atlas == null:
		return null
	return _reorder_to_canonical(webtyler_atlas, tile_size)


# 按输入格式分派到对应的 Webtyler 兼容转换路径。
static func _convert_to_webtyler_atlas(source: Image, input_format: StringName, tile_size: int) -> Image:
	match input_format:
		&"basic":
			return _convert_basic(source, tile_size)
		&"basicborder", &"basicfullborder":
			return _convert_basic_border(source, tile_size, input_format == &"basicfullborder")
		&"basiclongborder":
			return _convert_basic_long_border(source, tile_size)
		&"minitiles":
			return _convert_minitiles(source, tile_size)
		&"4x4":
			return _convert_4x4(source, tile_size)
		&"4x4plus":
			var atlas := _convert_4x4(source, tile_size)
			_apply_inner_corners(source, atlas, Vector2i(4, 0), tile_size)
			return atlas
		&"3x3":
			return _convert_3x3(source, tile_size)
		&"3x3plus":
			var atlas := _convert_3x3(source, tile_size)
			_apply_inner_corners(source, atlas, Vector2i(3, 0), tile_size)
			return atlas
		&"5x3":
			return _convert_5x3(source, tile_size)
		&"5x2":
			return _convert_5x2(source, tile_size)
		&"4x2":
			return _convert_4x2(source, tile_size)
		&"rpgmaker":
			return _convert_rpgmaker(source, tile_size)
	push_error("Unknown terrain input format: %s" % input_format)
	return null


# 将 Webtyler 的 12x4 Godot 3 atlas 按 canonical mask 升序重排为 8x6。
static func _reorder_to_canonical(webtyler_atlas: Image, tile_size: int) -> Image:
	var output := _create_image(CANONICAL_COLUMNS, CANONICAL_ROWS, tile_size)
	var source_by_mask := {}
	for webtyler_index in WEBTYLER_MASKS.size():
		var mask: int = WEBTYLER_MASKS[webtyler_index]
		if mask >= 0:
			source_by_mask[mask] = Vector2i(webtyler_index % WEBTYLER_COLUMNS, webtyler_index / WEBTYLER_COLUMNS)
	var masks := blob47_masks()
	for output_index in masks.size():
		_copy_tile(
			webtyler_atlas,
			output,
			Vector2i(output_index % CANONICAL_COLUMNS, output_index / CANONICAL_COLUMNS),
			source_by_mask[masks[output_index]],
			tile_size
		)
	return output


# 将 basic 两格输入扩展为五格 minitiles，再执行通用 minitiles 转换。
static func _convert_basic(source: Image, tile_size: int) -> Image:
	var minitiles := _create_image(5, 1, tile_size)
	_copy_tile(source, minitiles, Vector2i(0, 0), Vector2i(0, 0), tile_size)
	for target_x in range(1, 5):
		_copy_tile(source, minitiles, Vector2i(target_x, 0), Vector2i(1, 0), tile_size)
	return _convert_minitiles(minitiles, tile_size)


# 将 basic border 变体扩展为 Webtyler 的五格 minitiles。
static func _convert_basic_border(source: Image, tile_size: int, full_border: bool) -> Image:
	var minitiles := _create_image(5, 1, tile_size)
	_copy_tile(source, minitiles, Vector2i(0, 0), Vector2i(0, 0), tile_size)
	for target_x in range(1, 5):
		_copy_tile(source, minitiles, Vector2i(target_x, 0), Vector2i(1, 0), tile_size)
	var quarter := tile_size / 4
	var three_quarters := tile_size * 3 / 4
	var half := tile_size / 2
	_copy_pixels(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, quarter), Vector2i(0, quarter), Vector2i(half, three_quarters - quarter), tile_size)
	_copy_pixels(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, quarter), Vector2i(0, three_quarters), Vector2i(half, tile_size - three_quarters), tile_size)
	_copy_pixels(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, quarter + tile_size - three_quarters), Vector2i.ZERO, Vector2i(half, quarter), tile_size)
	_copy_pixels(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(half, quarter), Vector2i(half, quarter), Vector2i(tile_size - half, three_quarters - quarter), tile_size)
	_copy_pixels(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(half, quarter), Vector2i(half, three_quarters), Vector2i(tile_size - half, tile_size - three_quarters), tile_size)
	_copy_pixels(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(half, quarter + tile_size - three_quarters), Vector2i(half, 0), Vector2i(tile_size - half, quarter), tile_size)
	_copy_pixels(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(quarter, 0), Vector2i(quarter, 0), Vector2i(three_quarters - quarter, half), tile_size)
	_copy_pixels(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(quarter, 0), Vector2i(three_quarters, 0), Vector2i(tile_size - three_quarters, half), tile_size)
	_copy_pixels(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(quarter + tile_size - three_quarters, 0), Vector2i.ZERO, Vector2i(quarter, half), tile_size)
	_copy_pixels(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(quarter, half), Vector2i(quarter, half), Vector2i(three_quarters - quarter, tile_size - half), tile_size)
	_copy_pixels(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(quarter, half), Vector2i(three_quarters, half), Vector2i(tile_size - three_quarters, tile_size - half), tile_size)
	_copy_pixels(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(quarter + tile_size - three_quarters, half), Vector2i(0, half), Vector2i(quarter, tile_size - half), tile_size)
	if full_border:
		_copy_tile(source, minitiles, Vector2i(3, 0), Vector2i(2, 0), tile_size)
	return _convert_minitiles(minitiles, tile_size)


# 将 basic long border 的边框格扩展为四个方向格。
static func _convert_basic_long_border(source: Image, tile_size: int) -> Image:
	var minitiles := _create_image(5, 1, tile_size)
	for target_x in 4:
		_copy_tile(source, minitiles, Vector2i(target_x, 0), Vector2i(0, 0), tile_size)
	_copy_tile(source, minitiles, Vector2i(4, 0), Vector2i(1, 0), tile_size)
	return _convert_minitiles(minitiles, tile_size)


# 根据每个 quadrant 的邻接组合，从五格 minitiles 合成完整 Webtyler atlas。
static func _convert_minitiles(source: Image, tile_size: int) -> Image:
	var atlas := _create_image(WEBTYLER_COLUMNS, WEBTYLER_ROWS, tile_size)
	for target_index in WEBTYLER_MASKS.size():
		var mask: int = WEBTYLER_MASKS[target_index]
		if mask < 0:
			continue
		var target := Vector2i(target_index % WEBTYLER_COLUMNS, target_index / WEBTYLER_COLUMNS)
		for section_y in 3:
			for section_x in 3:
				var source_tile := _minitile_for_section(mask, Vector2i(section_x, section_y))
				_copy_tile_section(source, atlas, target, Vector2i(section_x, section_y), Vector2i(source_tile, 0), tile_size)
	return atlas


# 选择一个 quadrant 所需的 minitile 类型。
static func _minitile_for_section(mask: int, section: Vector2i) -> int:
	if section.x == 1 or section.y == 1:
		return 4
	var vertical_bit := 1 if section.y == 0 else 16
	var horizontal_bit := 64 if section.x == 0 else 4
	var corner_bit := 128
	if section == Vector2i(2, 0):
		corner_bit = 2
	elif section == Vector2i(2, 2):
		corner_bit = 8
	elif section == Vector2i(0, 2):
		corner_bit = 32
	var has_vertical := bool(mask & vertical_bit)
	var has_horizontal := bool(mask & horizontal_bit)
	if not has_vertical and not has_horizontal:
		return 0
	if has_vertical and not has_horizontal:
		return 1
	if has_horizontal and not has_vertical:
		return 2
	return 4 if mask & corner_bit else 3


# 按 Webtyler 的映射将 4x4 输入展开为旧 Godot atlas。
static func _convert_4x4(source: Image, tile_size: int) -> Image:
	var atlas := _create_image(WEBTYLER_COLUMNS, WEBTYLER_ROWS, tile_size)
	for target_index in FOUR_BY_FOUR_SOURCES.size():
		var source_index: int = FOUR_BY_FOUR_SOURCES[target_index]
		if source_index < 0:
			continue
		_copy_tile(
			source,
			atlas,
			Vector2i(target_index % WEBTYLER_COLUMNS, target_index / WEBTYLER_COLUMNS),
			Vector2i(source_index % 4, source_index / 4),
			tile_size
		)
	return atlas


# 将 3x3 输入按 quadrant 合成为 4x4，再复用 4x4 转换。
static func _convert_3x3(source: Image, tile_size: int) -> Image:
	var intermediate := _create_image(4, 4, tile_size)
	for target_y in 4:
		for target_x in 4:
			for section_y in 3:
				for section_x in 3:
					var target_index := target_y * 4 + target_x
					var section_index := section_y * 3 + section_x
					var source_index: int = THREE_BY_THREE_SECTION_SOURCES[target_index * 9 + section_index]
					_copy_tile_section(
						source,
						intermediate,
						Vector2i(target_x, target_y),
						Vector2i(section_x, section_y),
						Vector2i(source_index % 3, source_index / 3),
						tile_size
					)
	return _convert_4x4(intermediate, tile_size)


# 使用额外的 inner-corner tile 覆盖缺少 diagonal 邻接的 quadrant。
static func _apply_inner_corners(source: Image, atlas: Image, source_tile: Vector2i, tile_size: int) -> void:
	for target_index in WEBTYLER_MASKS.size():
		var mask: int = WEBTYLER_MASKS[target_index]
		if mask < 0:
			continue
		var target := Vector2i(target_index % WEBTYLER_COLUMNS, target_index / WEBTYLER_COLUMNS)
		if mask & 1 and mask & 64 and not mask & 128:
			_copy_tile_section(source, atlas, target, Vector2i(0, 0), source_tile, tile_size)
		if mask & 1 and mask & 4 and not mask & 2:
			_copy_tile_section(source, atlas, target, Vector2i(2, 0), source_tile, tile_size)
		if mask & 16 and mask & 4 and not mask & 8:
			_copy_tile_section(source, atlas, target, Vector2i(2, 2), source_tile, tile_size)
		if mask & 16 and mask & 64 and not mask & 32:
			_copy_tile_section(source, atlas, target, Vector2i(0, 2), source_tile, tile_size)


# 将 5x3 输入的边缘和 inner-corner 专用格应用到 3x3 基础结果。
static func _convert_5x3(source: Image, tile_size: int) -> Image:
	var atlas := _convert_3x3(source, tile_size)
	_apply_inner_corners(source, atlas, Vector2i(4, 0), tile_size)
	_copy_tile(source, atlas, Vector2i(0, 0), Vector2i(3, 0), tile_size)
	_copy_tile(source, atlas, Vector2i(0, 2), Vector2i(3, 1), tile_size)
	_copy_tile(source, atlas, Vector2i(0, 3), Vector2i(4, 1), tile_size)
	_copy_tile(source, atlas, Vector2i(1, 3), Vector2i(3, 2), tile_size)
	_copy_tile(source, atlas, Vector2i(3, 3), Vector2i(4, 2), tile_size)
	return atlas


# 将 5x2 输入补齐为 Webtyler 的 5x3 中间格式。
static func _convert_5x2(source: Image, tile_size: int) -> Image:
	var intermediate := _create_image(5, 3, tile_size)
	_copy_tile(source, intermediate, Vector2i(4, 1), Vector2i(3, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(4, 0), Vector2i(4, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(3, 2), Vector2i(3, 1), tile_size)
	_copy_tile(source, intermediate, Vector2i(4, 2), Vector2i(4, 1), tile_size)
	_copy_tile(source, intermediate, Vector2i(3, 0), Vector2i(2, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(3, 1), Vector2i(2, 1), tile_size)
	_copy_tile(source, intermediate, Vector2i(0, 0), Vector2i(0, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(0, 2), Vector2i(0, 1), tile_size)
	_copy_tile(source, intermediate, Vector2i(2, 0), Vector2i(1, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(2, 2), Vector2i(1, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 0), Vector2i(0, 0), Vector2i(4, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 0), Vector2i(1, 0), Vector2i(3, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 2), Vector2i(0, 1), Vector2i(4, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 2), Vector2i(1, 1), Vector2i(3, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 2), Vector2i(0, 0), Vector2i(1, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 2), Vector2i(1, 0), Vector2i(0, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(0, 1), Vector2i(0, 1), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(0, 1), Vector2i(0, 0), Vector2i(2, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(1, 1), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(1, 0), Vector2i(2, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(0, 0), Vector2i(1, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 1), Vector2i(1, 1), Vector2i(0, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), tile_size)
	return _convert_5x3(intermediate, tile_size)


# 将 4x2 输入补齐为 5x2，再复用 5x2 转换。
static func _convert_4x2(source: Image, tile_size: int) -> Image:
	var intermediate := _create_image(5, 2, tile_size)
	_copy_tile(source, intermediate, Vector2i(0, 0), Vector2i(0, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(0, 1), Vector2i(0, 1), tile_size)
	_copy_tile(source, intermediate, Vector2i(1, 0), Vector2i(1, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(1, 1), Vector2i(1, 1), tile_size)
	_copy_tile(source, intermediate, Vector2i(4, 0), Vector2i(3, 0), tile_size)
	_copy_tile(source, intermediate, Vector2i(3, 0), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 0), Vector2i(0, 0), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 0), Vector2i(1, 0), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(0, 0), Vector2i(2, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(1, 0), Vector2i(2, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(0, 1), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(2, 1), Vector2i(1, 1), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(3, 1), Vector2i(0, 0), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(3, 1), Vector2i(0, 1), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(3, 1), Vector2i(1, 0), Vector2i(3, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(3, 1), Vector2i(1, 1), Vector2i(3, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(4, 1), Vector2i(0, 0), Vector2i(3, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(4, 1), Vector2i(0, 1), Vector2i(3, 1), tile_size)
	_copy_quad(source, intermediate, Vector2i(4, 1), Vector2i(1, 0), Vector2i(2, 0), tile_size)
	_copy_quad(source, intermediate, Vector2i(4, 1), Vector2i(1, 1), Vector2i(2, 0), tile_size)
	return _convert_5x2(intermediate, tile_size)


# 将 RPG Maker 2x3 输入重组为五格 minitiles。
static func _convert_rpgmaker(source: Image, tile_size: int) -> Image:
	var minitiles := _create_image(5, 1, tile_size)
	_copy_quad(source, minitiles, Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), tile_size)
	_copy_quad(source, minitiles, Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 2), tile_size)
	_copy_quad(source, minitiles, Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 2), tile_size)
	_copy_quad(source, minitiles, Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 2), tile_size)
	_copy_quad(source, minitiles, Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), tile_size)
	_copy_quad(source, minitiles, Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 2), tile_size)
	_copy_tile(source, minitiles, Vector2i(3, 0), Vector2i(1, 0), tile_size)
	_copy_quad(source, minitiles, Vector2i(4, 0), Vector2i(1, 1), Vector2i(0, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(4, 0), Vector2i(0, 1), Vector2i(1, 1), tile_size)
	_copy_quad(source, minitiles, Vector2i(4, 0), Vector2i(1, 0), Vector2i(0, 2), tile_size)
	_copy_quad(source, minitiles, Vector2i(4, 0), Vector2i(0, 0), Vector2i(1, 2), tile_size)
	return _convert_minitiles(minitiles, tile_size)


# 创建指定 tile 网格大小的透明 RGBA8 图片。
static func _create_image(columns: int, rows: int, tile_size: int) -> Image:
	return Image.create(columns * tile_size, rows * tile_size, false, Image.FORMAT_RGBA8)


# 复制一整格 tile，并先清空目标区域。
static func _copy_tile(source: Image, target: Image, target_tile: Vector2i, source_tile: Vector2i, tile_size: int) -> void:
	var target_rect := Rect2i(target_tile * tile_size, Vector2i(tile_size, tile_size))
	target.fill_rect(target_rect, Color.TRANSPARENT)
	target.blit_rect(source, Rect2i(source_tile * tile_size, Vector2i(tile_size, tile_size)), target_rect.position)


# 复制 Webtyler 3x3 section 中的一块，默认 offset 为零。
static func _copy_tile_section(
		source: Image,
		target: Image,
		target_tile: Vector2i,
		section: Vector2i,
		source_tile: Vector2i,
		tile_size: int
	) -> void:
	var half := tile_size / 2
	var offsets := PackedInt32Array([0, half, half])
	var sizes := PackedInt32Array([half, 0, tile_size - half])
	var section_size := Vector2i(sizes[section.x], sizes[section.y])
	if section_size.x <= 0 or section_size.y <= 0:
		return
	var section_offset := Vector2i(offsets[section.x], offsets[section.y])
	var source_position := source_tile * tile_size + section_offset
	var target_position := target_tile * tile_size + section_offset
	target.fill_rect(Rect2i(target_position, section_size), Color.TRANSPARENT)
	target.blit_rect(source, Rect2i(source_position, section_size), target_position)


# 复制 tile 内任意像素矩形，用于 basic border 的边缘循环。
static func _copy_pixels(
		source: Image,
		target: Image,
		target_tile: Vector2i,
		source_tile: Vector2i,
		from: Vector2i,
		to: Vector2i,
		size: Vector2i,
		tile_size: int
	) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var source_position := source_tile * tile_size + from
	var target_position := target_tile * tile_size + to
	target.fill_rect(Rect2i(target_position, size), Color.TRANSPARENT)
	target.blit_rect(source, Rect2i(source_position, size), target_position)


# 复制 tile 的一个 quadrant，用于压缩格式的重组。
static func _copy_quad(
		source: Image,
		target: Image,
		target_tile: Vector2i,
		section: Vector2i,
		source_tile: Vector2i,
		tile_size: int
	) -> void:
	var half := tile_size / 2
	var offset := Vector2i(half if section.x else 0, half if section.y else 0)
	var size := Vector2i(tile_size - half if section.x else half, tile_size - half if section.y else half)
	var source_position := source_tile * tile_size + offset
	var target_position := target_tile * tile_size + offset
	target.fill_rect(Rect2i(target_position, size), Color.TRANSPARENT)
	target.blit_rect(source, Rect2i(source_position, size), target_position)
