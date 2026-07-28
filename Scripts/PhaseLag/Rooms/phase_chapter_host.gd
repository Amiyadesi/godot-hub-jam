class_name PhaseChapterHost
extends Node
## Owns every paired authored room in one continuous horizontal chapter.

signal chapter_loaded(chapter: ChapterDefinition)
signal room_activated(definition: PhaseRoomDefinition, room_index: int)
signal room_about_to_unload(definition: PhaseRoomDefinition)
signal room_reset(room_id: StringName)

@export var lu_mount_path: NodePath = ^"LuMount"
@export var xing_mount_path: NodePath = ^"XingMount"

var current_chapter: ChapterDefinition
var current_definition: PhaseRoomDefinition
var current_index: int = -1
var _definitions: Array[PhaseRoomDefinition] = []
var _lu_sides: Array[PhaseRoomSide] = []
var _xing_sides: Array[PhaseRoomSide] = []
var _active_room_frozen: bool = false

@onready var lu_mount: Node2D = get_node(lu_mount_path)
@onready var xing_mount: Node2D = get_node(xing_mount_path)


# Instantiates the complete authored chapter and activates one clean room pair.
func load_chapter(chapter: ChapterDefinition, start_index: int = 0) -> bool:
	if chapter == null:
		push_error("PhaseChapterHost requires an authored chapter")
		return false
	if chapter.flow_kind == ChapterDefinition.FLOW_FINALE:
		push_error("PhaseChapterHost does not load finale chapters")
		return false
	if chapter.flow_kind == ChapterDefinition.FLOW_ROOMS and chapter.rooms.is_empty():
		push_error("PhaseChapterHost room chapters require at least one authored room")
		return false
	if chapter.flow_kind == ChapterDefinition.FLOW_BOSS and (not chapter.rooms.is_empty() or chapter.boss_room == null):
		push_error("PhaseChapterHost Boss chapters require only one authored boss_room")
		return false
	if chapter.flow_kind == ChapterDefinition.FLOW_ROOMS and chapter.boss_room != null:
		push_error("PhaseChapterHost room chapters cannot append a Boss room")
		return false
	_clear_chapter()
	current_chapter = chapter
	if chapter.flow_kind == ChapterDefinition.FLOW_BOSS:
		_definitions.append(chapter.boss_room)
	else:
		_definitions.assign(chapter.rooms)
	var room_offset_x := 0.0
	for definition: PhaseRoomDefinition in _definitions:
		if not _validate_definition(definition):
			_clear_chapter()
			return false
		var pair := _instantiate_pair(definition, room_offset_x)
		if pair.is_empty():
			_clear_chapter()
			return false
		_lu_sides.append(pair[EntangledEntity.Side.LU_HENG])
		_xing_sides.append(pair[EntangledEntity.Side.XING_YAO])
		room_offset_x += float(definition.room_width_px)
	if not activate_room(clampi(start_index, 0, _definitions.size() - 1)):
		_clear_chapter()
		return false
	chapter_loaded.emit(chapter)
	return true


# Makes exactly one authored room pair interactive without freeing the chapter.
func activate_room(room_index: int) -> bool:
	if room_index < 0 or room_index >= _definitions.size():
		push_error("PhaseChapterHost room index %d is outside the loaded chapter" % room_index)
		return false
	for index in _definitions.size():
		var active := index == room_index
		_lu_sides[index].set_room_active(active)
		_xing_sides[index].set_room_active(active)
	current_index = room_index
	current_definition = _definitions[room_index]
	_apply_active_room_frozen_state()
	room_activated.emit(current_definition, current_index)
	return true


# Rebuilds only the active room pair and clears every in-flight causal change.
func reset_active_room() -> bool:
	if current_definition == null or current_index < 0:
		return false
	var definition := current_definition
	var old_lu_side := _lu_sides[current_index]
	var old_xing_side := _xing_sides[current_index]
	var room_offset_x := old_lu_side.position.x
	old_lu_side.prepare_for_unload()
	old_xing_side.prepare_for_unload()
	room_about_to_unload.emit(definition)
	EntanglementBus.reset_queue(true)
	lu_mount.remove_child(old_lu_side)
	xing_mount.remove_child(old_xing_side)
	old_lu_side.queue_free()
	old_xing_side.queue_free()
	var pair := _instantiate_pair(definition, room_offset_x)
	if pair.is_empty():
		return false
	_lu_sides[current_index] = pair[EntangledEntity.Side.LU_HENG]
	_xing_sides[current_index] = pair[EntangledEntity.Side.XING_YAO]
	_lu_sides[current_index].set_room_active(true)
	_xing_sides[current_index].set_room_active(true)
	_apply_active_room_frozen_state()
	room_reset.emit(definition.room_id)
	return true


# Freezes only the active authored room pair while retained players and HUD recover.
func set_active_room_frozen(value: bool) -> void:
	_active_room_frozen = value
	_apply_active_room_frozen_state()


# Applies the current recovery freeze to both active authored room roots.
func _apply_active_room_frozen_state() -> void:
	if current_index < 0:
		return
	var process_mode := Node.PROCESS_MODE_DISABLED if _active_room_frozen else Node.PROCESS_MODE_INHERIT
	get_lu_side().process_mode = process_mode
	get_xing_side().process_mode = process_mode


# Captures only stable already-arrived state under the active room pair.
func capture_active_room_state() -> Dictionary:
	if current_definition == null:
		return {}
	return {
		"room_id": current_definition.room_id,
		"lu_heng": get_lu_side().capture_persistent_state(),
		"xing_yao": get_xing_side().capture_persistent_state(),
	}


# Restores a clean active-room snapshot without replaying queued events.
func restore_active_room_state(state: Dictionary) -> bool:
	if current_definition == null or StringName(state.get("room_id", &"")) != current_definition.room_id:
		return false
	get_lu_side().restore_persistent_state(state.get("lu_heng", {}))
	get_xing_side().restore_persistent_state(state.get("xing_yao", {}))
	EntanglementBus.reset_queue(true)
	return true


# Returns one room side, defaulting to the active Lu Heng room.
func get_lu_side(room_index: int = -1) -> PhaseRoomSide:
	var index := current_index if room_index < 0 else room_index
	return _lu_sides[index] if index >= 0 and index < _lu_sides.size() else null


# Returns one room side, defaulting to the active Xing Yao room.
func get_xing_side(room_index: int = -1) -> PhaseRoomSide:
	var index := current_index if room_index < 0 else room_index
	return _xing_sides[index] if index >= 0 and index < _xing_sides.size() else null


# Returns authored metadata for one loaded room index.
func get_definition(room_index: int) -> PhaseRoomDefinition:
	return _definitions[room_index] if room_index >= 0 and room_index < _definitions.size() else null


# Returns the number of authored room pairs in the loaded chapter.
func get_room_count() -> int:
	return _definitions.size()


# Finds a saved authored room in the current chapter catalog.
func find_room_index(room_id: StringName) -> int:
	for index in _definitions.size():
		if _definitions[index].room_id == room_id:
			return index
	return -1


# Validates dimensions and paired authored scene contracts before instantiation.
func _validate_definition(definition: PhaseRoomDefinition) -> bool:
	if definition == null or definition.lu_heng_scene == null or definition.xing_yao_scene == null:
		push_error("PhaseChapterHost requires both authored side scenes")
		return false
	if definition.room_width_px < 1920 or definition.room_width_px % 32 != 0:
		push_error("Room %s width must be a 32px multiple at least 1920px" % definition.room_id)
		return false
	return true


# Instantiates one room pair at a shared horizontal chapter offset.
func _instantiate_pair(definition: PhaseRoomDefinition, room_offset_x: float) -> Dictionary:
	var lu_side := definition.lu_heng_scene.instantiate() as PhaseRoomSide
	var xing_side := definition.xing_yao_scene.instantiate() as PhaseRoomSide
	if lu_side == null or xing_side == null:
		push_error("Room %s side scenes must use PhaseRoomSide roots" % definition.room_id)
		return {}
	if lu_side.room_width_px != definition.room_width_px or xing_side.room_width_px != definition.room_width_px:
		push_error("Room %s authored side widths must both equal %dpx" % [definition.room_id, definition.room_width_px])
		lu_side.free()
		xing_side.free()
		return {}
	lu_side.position.x = room_offset_x
	xing_side.position.x = room_offset_x
	lu_side.configure_identity(definition.room_id, EntangledEntity.Side.LU_HENG, definition.room_width_px)
	xing_side.configure_identity(definition.room_id, EntangledEntity.Side.XING_YAO, definition.room_width_px)
	lu_mount.add_child(lu_side)
	xing_mount.add_child(xing_side)
	return {
		EntangledEntity.Side.LU_HENG: lu_side,
		EntangledEntity.Side.XING_YAO: xing_side,
	}


# Frees every loaded authored room before another chapter is composed.
func _clear_chapter() -> void:
	for side: PhaseRoomSide in _lu_sides:
		if is_instance_valid(side):
			side.prepare_for_unload()
	for side: PhaseRoomSide in _xing_sides:
		if is_instance_valid(side):
			side.prepare_for_unload()
	if current_definition != null:
		room_about_to_unload.emit(current_definition)
	for side: PhaseRoomSide in _lu_sides:
		if is_instance_valid(side):
			side.get_parent().remove_child(side)
			side.queue_free()
	for side: PhaseRoomSide in _xing_sides:
		if is_instance_valid(side):
			side.get_parent().remove_child(side)
			side.queue_free()
	_definitions.clear()
	_lu_sides.clear()
	_xing_sides.clear()
	current_chapter = null
	current_definition = null
	current_index = -1
	_active_room_frozen = false
