class_name PhaseRoomDefinition
extends Resource
## Read-only metadata pairing one authored room scene for each entangled universe.

@export var room_id: StringName = &"chapter_01_room_01"
@export var chapter_id: StringName = &"chapter_01"
@export_range(1, 4, 1) var room_number: int = 1
@export var display_name: String = "断线"
@export var lu_heng_scene: PackedScene
@export var xing_yao_scene: PackedScene
@export_range(1920, 8192, 32, "suffix:px") var room_width_px: int = 1920
@export_enum("陆衡", "星遥") var solo_entry_side: int = EntangledEntity.Side.LU_HENG
@export_enum("等分", "星遥主视角", "陆衡主视角", "错位重叠", "完全重合") var layout_mode: int = 0
@export var checkpoint_id: StringName = &"start"
@export var checkpoint_on_complete: bool = false
@export_range(-1.0, 6.0, 0.1, "suffix:s") var base_delay_override: float = -1.0
@export_range(-1.0, 6.0, 0.1, "suffix:s") var delay_after_completion: float = -1.0
@export var completion_links: Array[StringName] = []
@export var completion_values: Dictionary[StringName, bool] = {}
@export var auto_complete_on_load: bool = false
@export var opening_dialogue_title: StringName = &""
@export var completion_dialogue_title: StringName = &""
@export var hint_dialogue_title: StringName = &""
@export var is_boss_room: bool = false
