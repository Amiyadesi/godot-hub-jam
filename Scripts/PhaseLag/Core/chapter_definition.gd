class_name ChapterDefinition
extends Resource
## Authored chapter metadata shared by flow, HUD, checkpoints, and layout direction.

const FLOW_ROOMS: String = "rooms"
const FLOW_BOSS: String = "boss"
const FLOW_FINALE: String = "finale"

@export var chapter_id: StringName = &"chapter_01"
@export_range(1, 5, 1) var chapter_number: int = 1
@export var display_name: String = "隔岸"
@export_enum("rooms", "boss", "finale") var flow_kind: String = FLOW_ROOMS
@export_file("*.tscn") var chapter_scene_path: String = ""
@export_file("*.tscn") var next_scene_path: String = ""
@export_range(0.0, 6.0, 0.1, "suffix:s") var base_delay: float = 3.0
@export_enum("等分", "星遥 2/3", "陆衡 2/3", "错位重叠", "完全重合") var layout_mode: int = 0
@export var checkpoint_id: StringName = &"start"
@export var opening_dialogue_title: StringName = &""
@export var completion_dialogue_title: StringName = &""
@export var rooms: Array[PhaseRoomDefinition] = []
@export var boss_room: PhaseRoomDefinition
