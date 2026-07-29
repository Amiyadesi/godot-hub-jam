@tool
extends VBoxContainer

signal validate_requested(manifest_path: String)
signal generate_requested(manifest_path: String)

const ENTRY_ROW_SCENE := preload("res://addons/godot_terrain_authoring/ui/terrain_entry_row.tscn")

@onready var manifest_path_edit: LineEdit = %ManifestPathEdit
@onready var entries_container: VBoxContainer = %EntriesContainer
@onready var status_label: Label = %StatusLabel


# 请求只读验证当前 manifest。
func _on_validate_button_pressed() -> void:
	validate_requested.emit(manifest_path_edit.text.strip_edges())


# 请求生成 atlas 并更新目标 TileSet。
func _on_generate_button_pressed() -> void:
	generate_requested.emit(manifest_path_edit.text.strip_edges())


# 显示 manifest 中 authored Terrain 条目。
func show_manifest(manifest: TerrainAuthoringManifest) -> void:
	for child in entries_container.get_children():
		child.queue_free()
	for entry in manifest.terrain_entries:
		var row := ENTRY_ROW_SCENE.instantiate()
		entries_container.add_child(row)
		row.set_entry(entry)


# 更新插件操作结果，不隐藏错误。
func set_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.45, 0.45) if is_error else Color(0.65, 1.0, 0.75)
