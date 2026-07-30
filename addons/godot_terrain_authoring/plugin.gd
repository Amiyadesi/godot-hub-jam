@tool
extends EditorPlugin

const PANEL_SCENE := preload("res://addons/godot_terrain_authoring/ui/terrain_authoring_panel.tscn")

var panel: VBoxContainer


# 将 authored 面板加入 Godot 编辑器。
func _enter_tree() -> void:
	panel = PANEL_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)
	panel.validate_requested.connect(_on_validate_requested)
	panel.generate_requested.connect(_on_generate_requested)


# 从编辑器移除并释放面板。
func _exit_tree() -> void:
	remove_control_from_docks(panel)
	panel.queue_free()
	panel = null


# 只读加载并验证 manifest，显示每个 authored 条目。
func _on_validate_requested(manifest_path: String) -> void:
	var manifest := _load_manifest(manifest_path)
	if manifest == null:
		return
	panel.show_manifest(manifest)
	var errors := TerrainAuthoringPipeline.validate_manifest(manifest)
	if not errors.is_empty():
		panel.set_status("\n".join(errors), true)
		return
	panel.set_status("Valid: %d Terrain entries" % manifest.terrain_entries.size())


# 生成 atlas、重新导入纹理，并幂等更新目标 TileSet。
func _on_generate_requested(manifest_path: String) -> void:
	var manifest := _load_manifest(manifest_path)
	if manifest == null:
		return
	panel.show_manifest(manifest)
	# 先载入旧 TileSet，避免缩小同路径 atlas 时用新纹理解析旧 source。
	var tile_set := ResourceLoader.load(manifest.target_tileset_path, "TileSet", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	if tile_set == null:
		panel.set_status("Could not load target TileSet: %s" % manifest.target_tileset_path, true)
		return
	var generation_error := TerrainAuthoringPipeline.generate_and_save_atlas(manifest)
	if not generation_error.is_empty():
		panel.set_status(generation_error, true)
		return
	await _import_generated_atlas(manifest.output_atlas_path)
	var texture := ResourceLoader.load(manifest.output_atlas_path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	var build_error := GodotTerrainBuilder.augment_tileset(tile_set, texture, manifest, manifest_path)
	if not build_error.is_empty():
		panel.set_status(build_error, true)
		return
	var save_error := ResourceSaver.save(tile_set, manifest.target_tileset_path)
	if save_error != OK:
		panel.set_status("Could not save target TileSet (error %d)" % save_error, true)
		return
	EditorInterface.get_resource_filesystem().scan_sources()
	panel.set_status("Updated %s" % manifest.target_tileset_path)


# 先扫描新 PNG，再同步导入为 Texture2D。
func _import_generated_atlas(atlas_path: String) -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.scan_sources()
	while filesystem.is_scanning():
		await get_tree().process_frame
	filesystem.reimport_files(PackedStringArray([atlas_path]))


# 加载类型正确的 TerrainAuthoringManifest，否则明确报告。
func _load_manifest(manifest_path: String) -> TerrainAuthoringManifest:
	if manifest_path.is_empty() or not ResourceLoader.exists(manifest_path):
		panel.set_status("Manifest does not exist: %s" % manifest_path, true)
		return null
	var manifest := load(manifest_path) as TerrainAuthoringManifest
	if manifest == null:
		panel.set_status("Resource is not a TerrainAuthoringManifest: %s" % manifest_path, true)
		return null
	return manifest
