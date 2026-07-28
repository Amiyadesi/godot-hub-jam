class_name PhaseLagGame
extends Control
## Composition root for the three room chapters and the Boss-only fourth chapter.

enum LayoutMode {
	EQUAL,
	XING_FOCUS,
	LU_FOCUS,
	OFFSET_OVERLAP,
	MERGED,
}

const CHAPTERS: Array[ChapterDefinition] = [
	preload("res://resources/phase_lag/chapters/chapter_01.tres"),
	preload("res://resources/phase_lag/chapters/chapter_02.tres"),
	preload("res://resources/phase_lag/chapters/chapter_03.tres"),
	preload("res://resources/phase_lag/chapters/chapter_04.tres"),
]
const FINALE_CHAPTER: ChapterDefinition = preload("res://resources/phase_lag/chapters/chapter_05.tres")
const MENU_PATH: String = "res://Scenes/UI/Menu/menu.tscn"
const CHECKPOINT_BOSS: StringName = &"boss"
const DESIGN_WIDTH: int = 1920
const DESIGN_HEIGHT: int = 1080
const ROOM_HEIGHT: int = 704
const SUPPORT_HEIGHT: int = 352
const EQUAL_VIEW_HEIGHT: int = 528
const PHASE_SEAM_HEIGHT: int = 24

@export_range(0, 3, 1) var chapter_index: int = 0
@export var entry_transition: bool = false

var _chapter: ChapterDefinition
var _chapter_completing: bool = false
var _boss_started: bool = false
var _skip_boss_intro: bool = false
var _failure_in_progress: bool = false
var _refill_after_failure_reset: bool = false
var _layout_tween: Tween
var _teleport_layout_target: int = -1
var _room_index: int = 0
var _room_progress: Dictionary[StringName, bool] = {}
var _room_exits_reached: Dictionary[int, bool] = {0: false, 1: false}
var _room_anchors_reached: Dictionary[int, bool] = {0: false, 1: false}
var _room_solved: bool = false
var _room_completion_pending: bool = false
var _pending_room_refill: bool = true
var _pending_room_restore: Dictionary = {}
var _pending_room_completed: bool = false
var _room_transitioning: bool = false
var _transition_finished_sides: Dictionary[int, bool] = {0: false, 1: false}

@onready var xing_container: SubViewportContainer = %XingContainer
@onready var lu_container: SubViewportContainer = %LuContainer
@onready var xing_viewport: SubViewport = %XingViewport
@onready var lu_viewport: SubViewport = %LuViewport
@onready var xing_world: PhaseWorldSide = %XingWorld
@onready var lu_world: PhaseWorldSide = %LuWorld
@onready var boss_avatar: PhaseBossAvatar = %PhaseBossAvatar
@onready var game_mode: GameMode = %GameMode
@onready var boss_support: BossSupportObjective = %BossSupportObjective
@onready var boss_controller: PhaseBossController = %PhaseBossController
@onready var boss_visual_director: PhaseBossVisualDirector = %PhaseBossVisualDirector
@onready var room_host: PhaseChapterHost = %PhaseChapterHost
@onready var phase_seam_vfx: PhaseSeamVfx = %PhaseSeamVfx
@onready var audio_director: PhaseAudioDirector = %PhaseAudioDirector
@onready var dialogue_router: PhaseDialogueRouter = %PhaseDialogueRouter
@onready var hud: PhaseLagHUD = %PhaseLagHUD
@onready var pause_command_layer: PhasePauseCommandLayer = %PhasePauseCommandLayer
@onready var chapter_transition: PhaseChapterTransition = %PhaseChapterTransition
@onready var pause_screen: PauseScreen = %PauseScreen
@onready var setting_screen: SettingScreen = %SettingScreen


# Stops title music before authored chapter audio children enter the tree.
func _enter_tree() -> void:
	GameAudio.stop_music(0.0)


# Builds the active chapter from authored worlds, resources, UI, and global systems.
func _ready() -> void:
	get_tree().paused = false
	_chapter = CHAPTERS[chapter_index]
	assert(_chapter.flow_kind != ChapterDefinition.FLOW_FINALE, "PhaseLagGame cannot own finale chapters")
	audio_director.set_chapter(chapter_index)
	EntanglementBus.reset_queue(true)
	EntanglementBus.set_base_delay(_chapter.base_delay)
	_connect_signals()
	boss_controller.setup(lu_world, xing_world, lu_viewport, xing_viewport, boss_avatar, boss_support)
	boss_visual_director.setup(boss_controller, boss_support, boss_avatar, lu_world, xing_world)
	var saved_play_mode := LevelModule.instance.play_mode if LevelModule.instance != null else LevelModule.PLAY_MODE_SOLO
	game_mode.configure(saved_play_mode)
	_skip_boss_intro = _chapter.flow_kind == ChapterDefinition.FLOW_BOSS and _has_saved_boss_checkpoint()
	if not load_authored_room(_resolve_saved_room_index(), true):
		return
	pause_command_layer.set_available(false)
	hud.set_chapter(_chapter.chapter_number, _chapter.display_name)
	if entry_transition:
		chapter_transition.prepare_open(_chapter_transition_title(_chapter))
	else:
		chapter_transition.hide_immediately()
	phase_seam_vfx.set_delay(_chapter.base_delay)
	_record_chapter_start()
	call_deferred("_start_chapter_flow")


# Opens the authored pause surface after unhandled gameplay input.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _open_pause_menu():
		get_viewport().set_input_as_handled()


# Animates between equal, weighted, overlapping, and merged split layouts.
func apply_layout(mode: int, animate: bool = true) -> void:
	var lu_top: float = 0.0
	var lu_bottom: float = 0.5
	var xing_top: float = 0.5
	var xing_bottom: float = 1.0
	var lu_top_offset: float = 0.0
	var lu_bottom_offset: float = -PHASE_SEAM_HEIGHT * 0.5
	var xing_top_offset: float = PHASE_SEAM_HEIGHT * 0.5
	var xing_bottom_offset: float = 0.0
	var xing_alpha: float = 1.0
	var seam_upper_boundary: float = 0.5
	var seam_lower_boundary: float = 0.5
	match mode:
		LayoutMode.XING_FOCUS:
			seam_upper_boundary = float(SUPPORT_HEIGHT + PHASE_SEAM_HEIGHT / 2) / DESIGN_HEIGHT
			seam_lower_boundary = seam_upper_boundary
			lu_bottom = seam_upper_boundary
			xing_top = seam_lower_boundary
		LayoutMode.LU_FOCUS:
			seam_upper_boundary = float(ROOM_HEIGHT + PHASE_SEAM_HEIGHT / 2) / DESIGN_HEIGHT
			seam_lower_boundary = seam_upper_boundary
			lu_bottom = seam_upper_boundary
			xing_top = seam_lower_boundary
		LayoutMode.OFFSET_OVERLAP:
			lu_bottom = float(ROOM_HEIGHT) / DESIGN_HEIGHT
			xing_top = float(DESIGN_HEIGHT - ROOM_HEIGHT) / DESIGN_HEIGHT
			lu_bottom_offset = 0.0
			xing_top_offset = 0.0
			seam_upper_boundary = lu_bottom
			seam_lower_boundary = xing_top
			xing_container.z_index = 1
		LayoutMode.MERGED:
			lu_top = 0.0
			lu_bottom = 1.0
			xing_top = 0.0
			xing_bottom = 1.0
			lu_bottom_offset = 0.0
			xing_top_offset = 0.0
			xing_alpha = 0.48
			xing_container.z_index = 1
		_:
			xing_container.z_index = 0
	if mode != LayoutMode.OFFSET_OVERLAP and mode != LayoutMode.MERGED:
		xing_container.z_index = 0
	lu_container.z_index = 0
	var fill_merged_view := mode == LayoutMode.MERGED
	lu_world.set_full_viewport_fill(fill_merged_view)
	xing_world.set_full_viewport_fill(fill_merged_view)
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	var duration: float = 0.36 if animate else 0.0
	_layout_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_layout_tween.parallel().tween_property(xing_container, "anchor_top", xing_top, duration)
	_layout_tween.parallel().tween_property(xing_container, "anchor_bottom", xing_bottom, duration)
	_layout_tween.parallel().tween_property(xing_container, "offset_top", xing_top_offset, duration)
	_layout_tween.parallel().tween_property(xing_container, "offset_bottom", xing_bottom_offset, duration)
	_layout_tween.parallel().tween_property(lu_container, "anchor_top", lu_top, duration)
	_layout_tween.parallel().tween_property(lu_container, "anchor_bottom", lu_bottom, duration)
	_layout_tween.parallel().tween_property(lu_container, "offset_top", lu_top_offset, duration)
	_layout_tween.parallel().tween_property(lu_container, "offset_bottom", lu_bottom_offset, duration)
	_layout_tween.parallel().tween_property(xing_container, "modulate:a", xing_alpha, duration)
	_layout_tween.parallel().tween_property(lu_container, "modulate:a", 1.0, duration)
	phase_seam_vfx.apply_layout(mode, seam_upper_boundary, seam_lower_boundary, duration)
	var audio_weights := _layout_audio_weights(mode)
	audio_director.set_space_weights(audio_weights.x, audio_weights.y, duration)


# Converts one visual layout into matching Lu Heng and Xing Yao ambient weights.
func _layout_audio_weights(mode: int) -> Vector2:
	match mode:
		LayoutMode.XING_FOCUS:
			return Vector2(0.28, 1.0)
		LayoutMode.LU_FOCUS:
			return Vector2(1.0, 0.28)
		LayoutMode.OFFSET_OVERLAP:
			return Vector2(0.82, 0.82)
		LayoutMode.MERGED:
			return Vector2.ONE
		_:
			return Vector2(0.72, 0.72)


# Wires authored child signals to the one flow owner that can change chapters.
func _connect_signals() -> void:
	EntanglementBus.event_arrived.connect(_on_entanglement_event_arrived)
	EntanglementBus.delay_changed.connect(_on_delay_changed)
	for world: PhaseWorldSide in [lu_world, xing_world]:
		world.player_failed.connect(_on_player_failed)
		world.get_player().health_changed.connect(_on_player_health_changed.bind(world.side))
	game_mode.mode_changed.connect(_on_game_mode_changed)
	game_mode.active_side_changed.connect(_on_active_side_changed)
	game_mode.player_two_waiting.connect(_on_player_two_waiting)
	game_mode.player_two_connected.connect(_on_player_two_connected)
	game_mode.player_two_disconnected.connect(_on_player_two_disconnected)
	boss_controller.round_started.connect(_on_boss_round_started)
	boss_controller.teleport_warning.connect(_on_boss_teleport_warning)
	boss_controller.teleport_completed.connect(_on_boss_teleport_completed)
	boss_controller.defeated.connect(_on_boss_defeated)
	boss_controller.failed.connect(_on_boss_failed)
	room_host.room_activated.connect(_on_authored_room_loaded)
	room_host.room_reset.connect(_on_authored_room_reset)
	room_host.room_about_to_unload.connect(_on_authored_room_about_to_unload)
	lu_world.room_transition_finished.connect(_on_world_room_transition_finished)
	xing_world.room_transition_finished.connect(_on_world_room_transition_finished)
	hud.return_to_menu_requested.connect(_return_to_menu)
	pause_command_layer.pause_requested.connect(_open_pause_menu)
	pause_screen.continue_pressed.connect(_on_pause_continue)
	pause_screen.restart_pressed.connect(_on_pause_restart)
	pause_screen.hint_pressed.connect(_on_pause_hint)
	pause_screen.setting_pressed.connect(_on_pause_settings)
	pause_screen.quit_pressed.connect(_return_to_menu)
	setting_screen.visibility_changed.connect(_on_setting_screen_visibility_changed)


# Assigns P1 switching or fixed P1/P2 ownership to both authored players.
func _apply_input_ownership() -> void:
	if game_mode.mode == GameMode.Mode.LOCAL_COOP:
		lu_world.set_player_controlled(true, 1)
		xing_world.set_player_controlled(game_mode.is_player_two_ready(), 2)
	else:
		lu_world.set_player_controlled(game_mode.active_side == EntangledEntity.Side.LU_HENG, 1)
		xing_world.set_player_controlled(game_mode.active_side == EntangledEntity.Side.XING_YAO, 1)
	hud.set_mode(game_mode.mode, game_mode.active_side)


# Activates one room inside the already-composed horizontal chapter.
func load_authored_room(room_index: int, refill_health: bool = false) -> bool:
	var room_count := 1 if _chapter.flow_kind == ChapterDefinition.FLOW_BOSS else _chapter.rooms.size()
	if room_index < 0 or room_index >= room_count:
		push_error("PhaseLagGame.load_authored_room: room index %d is outside chapter %s" % [room_index, _chapter.chapter_id])
		return false
	var definition := _chapter.boss_room if _chapter.flow_kind == ChapterDefinition.FLOW_BOSS else _chapter.rooms[room_index]
	_room_index = room_index
	_room_progress.clear()
	_room_exits_reached = {0: false, 1: false}
	_room_anchors_reached = {0: false, 1: false}
	_room_solved = false
	_room_completion_pending = false
	game_mode.unlock_role_switch()
	_pending_room_refill = refill_health
	var saved_checkpoint := _saved_checkpoint_for_room(definition.room_id)
	_pending_room_restore = (saved_checkpoint.get("persistent_state", {}) as Dictionary).duplicate(true)
	_pending_room_completed = false
	EntanglementBus.reset_queue(true)
	if room_host.current_chapter == null:
		return room_host.load_chapter(_chapter, room_index)
	return room_host.activate_room(room_index)


# Resolves a room-aware save only when it belongs to this authored chapter catalog.
func _resolve_saved_room_index() -> int:
	if _chapter.flow_kind == ChapterDefinition.FLOW_BOSS:
		return 0
	if LevelModule.instance == null or LevelModule.instance.current_chapter_id != String(_chapter.chapter_id):
		return 0
	var checkpoint := LevelModule.instance.get_phase_checkpoint(String(_chapter.chapter_id))
	var room_id := StringName(checkpoint.get("room_id", &""))
	for index in _chapter.rooms.size():
		if _chapter.rooms[index].room_id == room_id:
			return index
	return 0


# Returns the current clean checkpoint only when it belongs to this authored room.
func _saved_checkpoint_for_room(room_id: StringName) -> Dictionary:
	if LevelModule.instance == null:
		return {}
	var checkpoint := LevelModule.instance.get_phase_checkpoint(String(_chapter.chapter_id))
	if StringName(checkpoint.get("room_id", &"")) != room_id:
		return {}
	return checkpoint


# Applies delay, layout, and automatic completion from read-only room metadata.
func _apply_room_definition(definition: PhaseRoomDefinition) -> void:
	var room_delay := definition.base_delay_override if definition.base_delay_override >= 0.0 else _chapter.base_delay
	EntanglementBus.set_base_delay(room_delay)
	var room_layout := LayoutMode.EQUAL if _chapter.chapter_id == &"chapter_02" else definition.layout_mode
	apply_layout(room_layout, false)
	phase_seam_vfx.set_delay(room_delay)
	if not definition.is_boss_room and (definition.auto_complete_on_load or definition.completion_links.is_empty()):
		_unlock_authored_room_exit()


# Connects an activated room and either snaps or pans both retained players into it.
func _on_authored_room_loaded(definition: PhaseRoomDefinition, _room_index_value: int) -> void:
	var lu_side := room_host.get_lu_side()
	var xing_side := room_host.get_xing_side()
	_connect_active_room_signals()
	if not _pending_room_restore.is_empty():
		room_host.restore_active_room_state(_pending_room_restore)
	_pending_room_restore = {}
	_apply_room_definition(definition)
	if _room_transitioning:
		_transition_finished_sides = {0: false, 1: false}
		lu_world.transition_to_room(lu_side, _pending_room_refill)
		xing_world.transition_to_room(xing_side, _pending_room_refill)
		return
	lu_world.bind_room(lu_side, _pending_room_refill)
	xing_world.bind_room(xing_side, _pending_room_refill)
	game_mode.set_active_side(definition.solo_entry_side)
	_apply_input_ownership()


# Rebinds retained players after the active room pair is rebuilt cleanly.
func _on_authored_room_reset(_room_id: StringName) -> void:
	var resolving_failure := _failure_in_progress
	var refill_players := _refill_after_failure_reset
	_refill_after_failure_reset = false
	_room_progress.clear()
	_room_exits_reached = {0: false, 1: false}
	_room_anchors_reached = {0: false, 1: false}
	_room_solved = false
	_room_completion_pending = false
	game_mode.unlock_role_switch()
	_connect_active_room_signals()
	lu_world.bind_room(room_host.get_lu_side(), refill_players)
	xing_world.bind_room(room_host.get_xing_side(), refill_players)
	_apply_room_definition(room_host.current_definition)
	game_mode.set_active_side(room_host.current_definition.solo_entry_side)
	if resolving_failure:
		lu_world.set_player_controlled(false, 1)
		xing_world.set_player_controlled(false, 1)
		call_deferred("_finish_failure_recovery")
		return
	_apply_input_ownership()
	_failure_in_progress = false


# Unlocks a rebuilt room only after authored nodes have completed one clean frame.
func _finish_failure_recovery() -> void:
	await get_tree().process_frame
	if not _failure_in_progress or room_host.current_definition == null:
		return
	room_host.set_active_room_frozen(false)
	game_mode.set_input_locked(false)
	_apply_input_ownership()
	hud.hide_timeline_collapse()
	get_tree().paused = false
	_failure_in_progress = false
	_refresh_pause_availability()


# Connects the current rebuilt room pair to the chapter flow owner exactly once.
func _connect_active_room_signals() -> void:
	for room_side: PhaseRoomSide in [room_host.get_lu_side(), room_host.get_xing_side()]:
		if not room_side.exit_reached.is_connected(_on_authored_room_exit):
			room_side.exit_reached.connect(_on_authored_room_exit)
		if not room_side.checkpoint_activated.is_connected(_on_authored_room_checkpoint_activated):
			room_side.checkpoint_activated.connect(_on_authored_room_checkpoint_activated)


# Releases Boss room references before an authored pair is destroyed during reset.
func _on_authored_room_about_to_unload(definition: PhaseRoomDefinition) -> void:
	if definition == null or not definition.is_boss_room:
		return
	boss_visual_director.unbind_authored_room()
	boss_controller.unbind_authored_room()


# Marks arrived room objective links and opens both exits only after the full authored set is true.
func _advance_authored_room(event: EntanglementEvent) -> void:
	if room_host.current_definition == null or room_host.current_definition.is_boss_room:
		return
	if not room_host.current_definition.completion_links.has(event.link_id):
		return
	var expected_value := bool(room_host.current_definition.completion_values.get(event.link_id, true))
	var arrived_value := bool(event.payload.get("value", true))
	if arrived_value != expected_value:
		return
	_room_progress[event.link_id] = true
	for link_id: StringName in room_host.current_definition.completion_links:
		if not _room_progress.get(link_id, false):
			return
	_unlock_authored_room_exit()


# Opens both authored exits after the room's real causal objectives have arrived.
func _unlock_authored_room_exit() -> void:
	if _room_solved or room_host.get_lu_side() == null or room_host.get_xing_side() == null:
		return
	_room_solved = true
	var completed_delay := room_host.current_definition.delay_after_completion
	if completed_delay >= 0.0:
		EntanglementBus.set_base_delay(completed_delay)
	room_host.get_lu_side().set_exit_enabled(true)
	room_host.get_xing_side().set_exit_enabled(true)


# Advances only when both authored players physically reach their enabled room exits.
func _on_authored_room_exit(side: int) -> void:
	_room_exits_reached[side] = true
	var departed_world := lu_world if side == EntangledEntity.Side.LU_HENG else xing_world
	departed_world.set_departed(true)
	if game_mode.mode == GameMode.Mode.SOLO:
		game_mode.lock_role_switch_until_room_change()
	if game_mode.mode == GameMode.Mode.SOLO and game_mode.active_side == side:
		var partner_side := 1 - side
		if not _room_exits_reached.get(partner_side, false):
			game_mode.set_active_side(partner_side)
	if not _room_exits_reached[0] or not _room_exits_reached[1]:
		return
	_complete_authored_room()


# Saves stable state at paired anchors and refills both fixed role health pools.
func _on_authored_room_checkpoint_activated(side: int, checkpoint_id: StringName) -> void:
	_room_anchors_reached[side] = true
	if not _room_anchors_reached[0] or not _room_anchors_reached[1]:
		return
	_store_authored_room_checkpoint(checkpoint_id)
	lu_world.get_player().set_health(lu_world.get_player().max_health)
	xing_world.get_player().set_health(xing_world.get_player().max_health)


# Stores the active room id and stable device paths without serializing queued events or health.
func _store_authored_room_checkpoint(checkpoint_id: StringName) -> void:
	if LevelModule.instance == null or room_host.current_definition == null:
		return
	LevelModule.instance.set_phase_checkpoint(
		String(_chapter.chapter_id),
		String(room_host.current_definition.room_id),
		String(checkpoint_id),
		room_host.capture_active_room_state()
	)
	SaveSystem.save_slot()


# Moves to the next authored room, enters the Boss room, or settles the current chapter.
func _complete_authored_room() -> void:
	if _room_completion_pending:
		return
	_room_completion_pending = true
	pause_command_layer.set_available(false)
	var completed_room := room_host.current_definition
	if completed_room.is_boss_room:
		return
	lu_world.set_player_controlled(false, 1)
	xing_world.set_player_controlled(false, 1)
	await _play_story_title(completed_room.completion_dialogue_title)
	if not is_instance_valid(self):
		return
	if _room_index + 1 < _chapter.rooms.size():
		var next_index := _room_index + 1
		if completed_room.checkpoint_on_complete:
			_store_room_start_checkpoint(_chapter.rooms[next_index], completed_room.checkpoint_id)
		_begin_room_transition(next_index, completed_room.checkpoint_on_complete)
		return
	_complete_chapter("因果闭环完成", false)


# Activates the next authored room while both viewport veils hide the camera pan.
func _begin_room_transition(next_index: int, refill_health: bool) -> void:
	_room_transitioning = true
	pause_command_layer.set_available(false)
	if not load_authored_room(next_index, refill_health):
		_room_transitioning = false


# Restores ownership after both universe cameras reach the next room.
func _on_world_room_transition_finished(side: int) -> void:
	_transition_finished_sides[side] = true
	if not _transition_finished_sides[0] or not _transition_finished_sides[1]:
		return
	_room_transitioning = false
	_pending_room_refill = false
	game_mode.set_active_side(room_host.current_definition.solo_entry_side)
	_apply_input_ownership()
	await _play_story_title(room_host.current_definition.opening_dialogue_title)
	if not is_instance_valid(self):
		return
	_refresh_pause_availability()


# Stores a clean next-room resume target after a completed checkpoint segment.
func _store_room_start_checkpoint(definition: PhaseRoomDefinition, checkpoint_id: StringName) -> void:
	if LevelModule.instance == null or definition == null:
		return
	LevelModule.instance.set_phase_checkpoint(
		String(_chapter.chapter_id),
		String(definition.room_id),
		String(checkpoint_id),
		{}
	)
	SaveSystem.save_slot()


# Records the current chapter without replacing a valid checkpoint in that same chapter.
func _record_chapter_start() -> void:
	if LevelModule.instance == null:
		return
	LevelModule.instance.enter_chapter(String(_chapter.chapter_id))
	SaveSystem.save_slot()


# Starts the authored room flow or the Boss-only fourth chapter after co-op is ready.
func _start_chapter_flow() -> void:
	if game_mode.mode == GameMode.Mode.LOCAL_COOP and not game_mode.is_player_two_ready():
		await game_mode.player_two_connected
	if entry_transition:
		await chapter_transition.play_open(_chapter_transition_title(_chapter))
		entry_transition = false
	if _chapter.flow_kind == ChapterDefinition.FLOW_BOSS:
		if not _skip_boss_intro:
			await _play_story_title(_chapter.opening_dialogue_title)
		if not is_instance_valid(self):
			return
		_store_boss_checkpoint()
		_enter_boss()
		_refresh_pause_availability()
		return
	if _room_index == 0:
		await _play_story_title(_chapter.opening_dialogue_title)
	elif room_host.current_definition != null:
		await _play_story_title(room_host.current_definition.opening_dialogue_title)
	_refresh_pause_availability()


# Detects a clean Boss checkpoint so Continue can skip only the entry conversation.
func _has_saved_boss_checkpoint() -> bool:
	if LevelModule.instance == null or LevelModule.instance.current_chapter_id != String(_chapter.chapter_id):
		return false
	var checkpoint := LevelModule.instance.get_phase_checkpoint(String(_chapter.chapter_id))
	return (
		StringName(checkpoint.get("room_id", &"")) == _chapter.boss_room.room_id
		and StringName(checkpoint.get("checkpoint_id", &"")) == CHECKPOINT_BOSS
	)


# Stores the single stable retry point owned by the Boss-only chapter.
func _store_boss_checkpoint() -> void:
	if LevelModule.instance == null or room_host.current_definition == null:
		return
	LevelModule.instance.set_phase_checkpoint(
		String(_chapter.chapter_id),
		String(room_host.current_definition.room_id),
		String(CHECKPOINT_BOSS),
		room_host.capture_active_room_state()
	)
	SaveSystem.save_slot()


# Waits for any radio bark, then owns one critical Dialogue Manager story through END.
func _play_story_title(title: StringName) -> void:
	if title.is_empty():
		return
	pause_command_layer.set_available(false)
	while dialogue_router.is_busy():
		await dialogue_router.dialogue_finished
	var started := dialogue_router.play_story(title)
	assert(started, "PhaseLagGame failed to start authored story title '%s'" % title)
	if started:
		await dialogue_router.story_finished
	_refresh_pause_availability()


# Marks one arriving link and advances only the active chapter's authored sequence.
func _on_entanglement_event_arrived(event: EntanglementEvent) -> void:
	_advance_authored_room(event)


# Enters round one at chapter four's authored boss room.
func _enter_boss() -> void:
	if _boss_started:
		return
	var lu_side := room_host.get_lu_side()
	var xing_side := room_host.get_xing_side()
	if room_host.current_definition == null or not room_host.current_definition.is_boss_room:
		push_error("PhaseLagGame._enter_boss requires the authored Boss room")
		return
	if not boss_controller.bind_authored_room(lu_side, xing_side):
		return
	if not boss_visual_director.bind_authored_room(lu_side, xing_side):
		boss_controller.unbind_authored_room()
		return
	_boss_started = true
	audio_director.play_battle()
	_store_boss_checkpoint()
	boss_controller.start_boss()
	_apply_input_ownership()


# Updates the merged-space seam after any future-event delay change.
func _on_delay_changed(seconds: float) -> void:
	phase_seam_vfx.set_delay(seconds)


# Updates player ownership after the save-authored mode is applied.
func _on_game_mode_changed(_mode: GameMode.Mode) -> void:
	_apply_input_ownership()


# Updates player ownership after a solo role handoff.
func _on_active_side_changed(_side: int) -> void:
	_apply_input_ownership()


# Pauses local co-op until its first P2 controller is available.
func _on_player_two_waiting() -> void:
	get_tree().paused = true
	hud.show_player_two_waiting(false)


# Restores fixed role ownership as soon as any controller reconnects.
func _on_player_two_connected(_device: int) -> void:
	hud.hide_player_two_waiting()
	_apply_input_ownership()
	get_tree().paused = dialogue_router.is_story_active()
	_refresh_pause_availability()


# Pauses the timeline and shows the authored P2 reconnect panel.
func _on_player_two_disconnected(_device: int) -> void:
	get_tree().paused = true
	_apply_input_ownership()
	hud.show_player_two_waiting(true)


# Updates one role's health block after damage or checkpoint reset.
func _on_player_health_changed(_player: PhasePlayer, health: int, _maximum: int, side: int) -> void:
	hud.set_health(side, health)


# Routes any player death or fall into the chapter-appropriate reset rule.
func _on_player_failed(_side: int, reason: StringName) -> void:
	_handle_timeline_failure("角色失败：%s" % String(reason))


# Applies the current boss side-weighted layout without explanatory text.
func _on_boss_round_started(_round_index: int) -> void:
	apply_layout(LayoutMode.LU_FOCUS if boss_controller.current_side == EntangledEntity.Side.LU_HENG else LayoutMode.XING_FOCUS)


# Moves visual weight toward the target universe once per teleport.
func _on_boss_teleport_warning(target_side: int, _seconds: float) -> void:
	if _teleport_layout_target == target_side:
		return
	_teleport_layout_target = target_side
	apply_layout(LayoutMode.LU_FOCUS if target_side == EntangledEntity.Side.LU_HENG else LayoutMode.XING_FOCUS)


# Clears layout warning state after the single body has changed SubViewports.
func _on_boss_teleport_completed(current_side: int) -> void:
	_teleport_layout_target = -1
	apply_layout(LayoutMode.LU_FOCUS if current_side == EntangledEntity.Side.LU_HENG else LayoutMode.XING_FOCUS)


# Completes chapter four after the three boss support rounds close.
func _on_boss_defeated() -> void:
	apply_layout(LayoutMode.EQUAL)
	_complete_chapter("相位猎手已解体 · 零延迟核心取得")


# Routes boss support timeout into the shared timeline collapse.
func _on_boss_failed(reason: String) -> void:
	_handle_timeline_failure(reason)


# Shows collapse feedback, clears transient state, then schedules one deferred recovery.
func _handle_timeline_failure(reason: String) -> void:
	if _failure_in_progress:
		return
	_failure_in_progress = true
	pause_command_layer.set_available(false)
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = null
	_room_transitioning = false
	_transition_finished_sides = {0: false, 1: false}
	_teleport_layout_target = -1
	EntanglementBus.reset_queue(true)
	game_mode.set_input_locked(true)
	lu_world.cancel_transient_state()
	xing_world.cancel_transient_state()
	# A lethal enemy hit can enter this handler from inside that enemy's physics callback.
	# Freeze after the callback returns so CharacterBody2D does not lose its space before move_and_slide().
	room_host.call_deferred("set_active_room_frozen", true)
	lu_world.get_player().set_controlled(false)
	xing_world.get_player().set_controlled(false)
	get_tree().paused = false
	hud.show_timeline_collapse(reason)
	await get_tree().create_timer(2.2, true).timeout
	if not is_instance_valid(self):
		return
	get_tree().paused = false
	if _chapter.flow_kind == ChapterDefinition.FLOW_BOSS:
		game_mode.set_input_locked(false)
		hud.hide_timeline_collapse()
		SceneManager.change_scene_to_file(MENU_PATH)
	else:
		_reset_after_failure()


# Rebuilds the active room outside the failure callback and keeps the overlay until rebinding finishes.
func _reset_after_failure() -> void:
	if not _failure_in_progress:
		return
	get_tree().paused = false
	if room_host.current_definition == null:
		_reload_after_failed_reset()
		return
	_refill_after_failure_reset = true
	if not room_host.reset_active_room():
		_reload_after_failed_reset()


# Falls back to the authored scene manager when the active room cannot be reconstructed.
func _reload_after_failed_reset() -> void:
	_refill_after_failure_reset = false
	room_host.set_active_room_frozen(false)
	game_mode.set_input_locked(false)
	hud.hide_timeline_collapse()
	_failure_in_progress = false
	get_tree().paused = false
	var error := SceneManager.reload_current_scene()
	if error != OK:
		push_error("PhaseLagGame could not reload after room reset failure: %s" % error_string(error))


# Persists completion, optionally plays the chapter close, then loads the next scene.
func _complete_chapter(_message: String = "因果闭环完成", play_dialogue: bool = true) -> void:
	if _chapter_completing:
		return
	_chapter_completing = true
	pause_command_layer.set_available(false)
	lu_world.set_player_controlled(false, 1)
	xing_world.set_player_controlled(false, 1)
	if LevelModule.instance != null:
		var next_chapter_id := "" if _chapter.next_scene_path.is_empty() else "chapter_%02d" % (_chapter.chapter_number + 1)
		LevelModule.instance.complete_chapter(String(_chapter.chapter_id), next_chapter_id)
		SaveSystem.save_slot()
	if play_dialogue:
		await _play_story_title(_chapter.completion_dialogue_title)
		if not is_instance_valid(self):
			return
	var next_chapter := CHAPTERS[chapter_index + 1] if chapter_index + 1 < CHAPTERS.size() else FINALE_CHAPTER
	await chapter_transition.play_close(_chapter_transition_title(next_chapter))
	if not is_instance_valid(self):
		return
	if _chapter.next_scene_path.is_empty():
		_return_to_menu()
	else:
		SceneManager.change_scene_to_file(_chapter.next_scene_path, {"entry_transition": true})


# Formats one authored chapter identity for the center-line transition.
func _chapter_transition_title(chapter: ChapterDefinition) -> String:
	var labels: Array[String] = ["零", "一", "二", "三", "四", "五"]
	var number_text := labels[chapter.chapter_number] if chapter.chapter_number < labels.size() else str(chapter.chapter_number)
	return "第%s章 · %s" % [number_text, chapter.display_name]


# Resumes play from the authored pause screen.
func _on_pause_continue() -> void:
	var tween := pause_screen.close_modal()
	if tween != null:
		await tween.finished
	get_tree().paused = false
	_refresh_pause_availability()


# Opens the pause layer from keyboard, controller, or the authored HUD button.
func _open_pause_menu() -> bool:
	if get_tree().paused or _chapter_completing or _failure_in_progress:
		return false
	var definition := room_host.current_definition
	var hint_available := (
		definition != null
		and not definition.hint_dialogue_title.is_empty()
		and not dialogue_router.is_busy()
	)
	pause_screen.set_hint_available(hint_available)
	pause_command_layer.set_available(false)
	get_tree().paused = true
	pause_screen.open_modal()
	return true


# Rebuilds the active authored room from its stable start via the pause layer.
func _on_pause_restart() -> void:
	pause_command_layer.set_available(false)
	pause_screen.close_modal()
	get_tree().paused = false
	EntanglementBus.reset_queue(true)
	if _chapter.flow_kind == ChapterDefinition.FLOW_BOSS:
		var boss_reload_error := SceneManager.reload_current_scene()
		if boss_reload_error != OK:
			push_error("PhaseLagGame could not restart the Boss room: %s" % error_string(boss_reload_error))
		return
	if room_host.reset_active_room():
		return
	var reload_error := SceneManager.reload_current_scene()
	if reload_error != OK:
		push_error("PhaseLagGame could not restart the active room: %s" % error_string(reload_error))


# Plays the active room's authored hint only after the player explicitly asks.
func _on_pause_hint() -> void:
	var definition := room_host.current_definition
	pause_command_layer.set_available(false)
	pause_screen.close_modal()
	get_tree().paused = false
	if definition == null or definition.hint_dialogue_title.is_empty():
		_refresh_pause_availability()
		return
	await get_tree().process_frame
	if not dialogue_router.play_bark(definition.hint_dialogue_title):
		push_warning("PhaseLagGame could not start room hint '%s'" % definition.hint_dialogue_title)
	_refresh_pause_availability()


# Hands the paused game to the existing authored settings modal.
func _on_pause_settings() -> void:
	pause_command_layer.set_available(false)
	pause_screen.close_modal()
	setting_screen.is_in_menu_flag = false
	setting_screen.open_modal()


# Restores the pause command after the in-game settings modal fully closes.
func _on_setting_screen_visibility_changed() -> void:
	if not setting_screen.visible:
		_refresh_pause_availability()


# Enables pause only during unobstructed, connected, non-transitioning gameplay.
func _refresh_pause_availability() -> void:
	var coop_ready := game_mode.mode != GameMode.Mode.LOCAL_COOP or game_mode.is_player_two_ready()
	var available := (
		not get_tree().paused
		and not _chapter_completing
		and not _failure_in_progress
		and not _room_completion_pending
		and not _room_transitioning
		and not dialogue_router.is_story_active()
		and not setting_screen.visible
		and coop_ready
	)
	pause_command_layer.set_available(available)


# Clears paused state and returns to the title scene.
func _return_to_menu() -> void:
	get_tree().paused = false
	EntanglementBus.reset_queue(true)
	SceneManager.change_scene_to_file(MENU_PATH)
