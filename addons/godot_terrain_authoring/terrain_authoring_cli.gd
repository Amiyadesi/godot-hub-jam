@tool
extends SceneTree


# 延迟一帧执行，使 editor filesystem 已完成初始化。
func _init() -> void:
	call_deferred("_run")


# 从命令行读取 manifest，生成 atlas 并安全更新 TileSet。
func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var validate_only := arguments.has("--validate-only")
	if not Engine.is_editor_hint() and not validate_only:
		_fail("Terrain authoring CLI must run with --editor")
		return
	if Engine.is_editor_hint():
		await _wait_for_editor_filesystem()
	var manifest_path := _read_manifest_path(arguments)
	if manifest_path.is_empty():
		_fail("Usage: -- --manifest <res://manifest.tres>")
		return
	var manifest := load(manifest_path) as TerrainAuthoringManifest
	if manifest == null:
		_fail("Could not load TerrainAuthoringManifest: %s" % manifest_path)
		return
	if validate_only:
		var validation_errors := TerrainAuthoringPipeline.validate_manifest(manifest)
		if not validation_errors.is_empty():
			_fail("\n".join(validation_errors))
			return
		print("Terrain authoring manifest valid: %s" % manifest_path)
		quit(0)
		return
	# 先载入旧 TileSet，避免缩小同路径 atlas 时用新纹理解析旧 source。
	var tile_set := ResourceLoader.load(manifest.target_tileset_path, "TileSet", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	if tile_set == null:
		_fail("Could not load target TileSet: %s" % manifest.target_tileset_path)
		return
	var generation_error := TerrainAuthoringPipeline.generate_and_save_atlas(manifest)
	if not generation_error.is_empty():
		_fail(generation_error)
		return
	await _import_generated_atlas(manifest.output_atlas_path)
	var texture := ResourceLoader.load(manifest.output_atlas_path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	if texture == null:
		_fail("Generated terrain atlas was not imported: %s" % manifest.output_atlas_path)
		return
	var build_error := GodotTerrainBuilder.augment_tileset(tile_set, texture, manifest, manifest_path)
	if not build_error.is_empty():
		_fail(build_error)
		return
	var save_error := ResourceSaver.save(tile_set, manifest.target_tileset_path)
	if save_error != OK:
		_fail("Could not save target TileSet %s (error %d)" % [manifest.target_tileset_path, save_error])
		return
	EditorInterface.get_resource_filesystem().scan_sources()
	print("Terrain authoring complete: %s" % manifest.target_tileset_path)
	quit(0)


# 先让 editor filesystem 发现新 PNG，再执行同步导入。
func _import_generated_atlas(atlas_path: String) -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.scan_sources()
	while filesystem.is_scanning():
		await process_frame
	filesystem.reimport_files(PackedStringArray([atlas_path]))


# 等待编辑器完成初始资源扫描，避免脚本退出时中断扫描线程。
func _wait_for_editor_filesystem() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.scan_sources()
	while filesystem.is_scanning():
		await process_frame


# 解析 `--manifest` 后的 res:// 资源路径。
func _read_manifest_path(arguments: PackedStringArray) -> String:
	for index in arguments.size():
		if arguments[index] == "--manifest" and index + 1 < arguments.size():
			return arguments[index + 1]
	return ""


# 输出明确错误并以失败状态退出。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
