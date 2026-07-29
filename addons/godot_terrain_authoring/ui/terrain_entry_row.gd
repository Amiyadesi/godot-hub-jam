@tool
extends HBoxContainer

@onready var name_label: Label = %NameLabel
@onready var format_label: Label = %FormatLabel
@onready var set_label: Label = %SetLabel
@onready var origin_label: Label = %OriginLabel


# 将一个 manifest 条目显示为只读摘要行。
func set_entry(entry: TerrainInputSpec) -> void:
	name_label.text = entry.terrain_name
	format_label.text = entry.input_format
	set_label.text = "Set %d" % entry.terrain_set_index
	origin_label.text = "(%d, %d)" % [entry.source_origin_tiles.x, entry.source_origin_tiles.y]
