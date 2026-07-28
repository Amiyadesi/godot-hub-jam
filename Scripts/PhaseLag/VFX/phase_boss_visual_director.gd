class_name PhaseBossVisualDirector
extends Node
## Routes explicit authored Boss links and structured state into nonverbal visual cues.

var _controller: PhaseBossController
var _support: BossSupportObjective
var _avatar: PhaseBossAvatar
var _lu_world: PhaseWorldSide
var _xing_world: PhaseWorldSide
var _trap_pipelines: Dictionary[StringName, PhaseCausalPipeline] = {}
var _active_round: int = 0
var _trap_id: StringName = &""
var _trap_center_time: float = 0.0
var _trap_tolerance: float = 0.0
var _teleport_target: int = -1
var _low_flash_mode: bool = false
var _routed_queued_sequences: Array[int] = []
var _routed_arrived_sequences: Array[int] = []


# Connects deterministic event routing and the persisted accessibility preference.
func _ready() -> void:
	EntanglementBus.event_queued.connect(_on_event_queued)
	EntanglementBus.event_arrived.connect(_on_event_arrived)
	EntanglementBus.queue_reset.connect(_on_queue_reset)
	_low_flash_mode = _read_low_flash_mode()
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)


# Injects the single Boss body, structured mechanism state, and both retained universes.
func setup(
		controller: PhaseBossController,
		support: BossSupportObjective,
		avatar: PhaseBossAvatar,
		lu_world: PhaseWorldSide,
		xing_world: PhaseWorldSide
	) -> void:
	_controller = controller
	_support = support
	_avatar = avatar
	_lu_world = lu_world
	_xing_world = xing_world
	_controller.round_started.connect(_on_round_started)
	_controller.teleport_warning.connect(_on_teleport_warning)
	_controller.teleport_completed.connect(_on_teleport_completed)
	_controller.trap_window_opened.connect(_on_trap_window_opened)
	_controller.trap_resolved.connect(_on_trap_resolved)
	_controller.final_window_changed.connect(_on_final_window_changed)
	_avatar.set_low_flash_mode(_low_flash_mode)


# Binds the physical Lu Heng trap pipeline used for calibration symbols and misses.
func bind_authored_room(lu_side: PhaseRoomSide, _xing_side: PhaseRoomSide) -> bool:
	unbind_authored_room()
	if lu_side == null:
		push_error("PhaseBossVisualDirector.bind_authored_room requires the Lu Heng Boss room")
		return false
	_trap_pipelines = {
		&"clamp": lu_side.get_node_or_null("Mechanisms/ClampPipeline") as PhaseCausalPipeline,
	}
	for trap_id: StringName in PhaseBossController.TRAP_ORDER:
		if _trap_pipelines.get(trap_id) == null:
			push_error("PhaseBossVisualDirector authored room is missing trap pipeline '%s'" % trap_id)
			return false
	return true


# Releases every room-local pipeline reference before the authored Boss room is replaced or freed.
func unbind_authored_room() -> void:
	_clear_bound_pipeline_visuals()
	_trap_pipelines.clear()
	_trap_id = &""
	_trap_center_time = 0.0
	_trap_tolerance = 0.0


# Counts live authored pipeline references for lifecycle and integration inspection.
func bound_authored_pipeline_count() -> int:
	var count: int = 0
	for pipeline_value: Variant in _trap_pipelines.values():
		if is_instance_valid(pipeline_value):
			count += 1
	return count


# Reports how many explicit Boss sends were routed by the visual director.
func routed_queued_count() -> int:
	return _routed_queued_sequences.size()


# Reports how many explicit Boss arrivals were routed by the visual director.
func routed_arrived_count() -> int:
	return _routed_arrived_sequences.size()


# Resets the visual grammar for one newly active authored mechanism round.
func _on_round_started(round_index: int) -> void:
	_active_round = round_index
	_trap_id = &""
	_avatar.set_round_visual(round_index)
	for trap_id: StringName in _trap_pipelines:
		var pipeline := _trap_pipelines[trap_id] as PhaseCausalPipeline
		pipeline.clear_boss_symbol()
		if round_index == 2:
			pipeline.set_boss_symbol(_trap_index(trap_id), true)


# Routes queued armor, trap, and final-power links without parsing generated names.
func _on_event_queued(event: EntanglementEvent) -> void:
	if not _is_boss_link(event.link_id):
		return
	_routed_queued_sequences.append(event.sequence)
	var duration := maxf(event.arrival_time - event.sent_time, 0.0)
	if PhaseBossController.ARMOR_LINKS.has(event.link_id):
		_avatar.begin_armor_crack(_armor_index(event.link_id), duration)
	elif PhaseBossController.TRAP_LINKS.has(event.link_id):
		var trap_id: StringName = PhaseBossController.TRAP_LINKS[event.link_id]
		var success := trap_id == _trap_id and absf(event.arrival_time - _trap_center_time) <= _trap_tolerance
		var pipeline := _trap_pipelines.get(trap_id) as PhaseCausalPipeline
		if pipeline != null:
			pipeline.lock_boss_calibration(success)
	elif event.link_id == PhaseBossController.FINAL_POWER_LINK:
		_avatar.begin_final_power_charge(duration)


# Completes armor and final-power cues at the real deterministic arrival time.
func _on_event_arrived(event: EntanglementEvent) -> void:
	if not _is_boss_link(event.link_id):
		return
	_routed_arrived_sequences.append(event.sequence)
	if PhaseBossController.ARMOR_LINKS.has(event.link_id):
		_avatar.break_armor_plate(_armor_index(event.link_id))
	elif event.link_id == PhaseBossController.FINAL_POWER_LINK and bool(event.payload.get("value", false)):
		_avatar.complete_final_power_half()


# Opens the matching authored pipeline ring at its exact local send center.
func _on_trap_window_opened(trap_id: StringName, center_time: float, tolerance: float) -> void:
	_trap_id = trap_id
	_trap_center_time = center_time
	_trap_tolerance = tolerance
	var pipeline := _trap_pipelines.get(trap_id) as PhaseCausalPipeline
	if pipeline != null:
		pipeline.begin_boss_calibration(_trap_index(trap_id), center_time - _trap_line_delay(trap_id))
	_avatar.show_trap_target(_trap_index(trap_id))


# Shows a successful clamp or a broken calibration ring without explanatory text.
func _on_trap_resolved(trap_id: StringName, success: bool) -> void:
	var pipeline := _trap_pipelines.get(trap_id) as PhaseCausalPipeline
	if pipeline != null:
		pipeline.resolve_boss_calibration(success)
	_avatar.resolve_trap(_trap_index(trap_id), success)


# Starts visual decay on arrived power or closes both halves after the heavy strike.
func _on_final_window_changed(has_power: bool, has_core: bool, seconds_left: float) -> void:
	if has_power and has_core:
		_avatar.complete_final_strike_half()
		_avatar.close_final_core()
	elif has_power:
		_avatar.show_final_window(true, false, seconds_left)


# Starts source dissolution and target-space materialization once per teleport.
func _on_teleport_warning(target_side: int, seconds: float) -> void:
	if _teleport_target == target_side:
		return
	_teleport_target = target_side
	var source_world := _world_for_side(1 - target_side)
	var target_world := _world_for_side(target_side)
	source_world.show_boss_afterimage(_avatar.position)
	target_world.show_boss_arrival_preview(seconds)
	_avatar.begin_telegraph(seconds)


# Restores the solid body after it physically reparents into the target SubViewport.
func _on_teleport_completed(current_side: int) -> void:
	_teleport_target = -1
	_world_for_side(current_side).clear_boss_arrival_preview()
	_avatar.end_telegraph()


# Clears every transient Boss cue when the active timeline queue resets.
func _on_queue_reset() -> void:
	_routed_queued_sequences.clear()
	_routed_arrived_sequences.clear()
	_teleport_target = -1
	if is_instance_valid(_avatar):
		_avatar.clear_boss_event_visuals()
	_clear_bound_pipeline_visuals()
	if is_instance_valid(_lu_world):
		_lu_world.clear_boss_visuals()
	if is_instance_valid(_xing_world):
		_xing_world.clear_boss_visuals()


# Clears only live pipeline cues so queue resets remain safe across authored room replacement.
func _clear_bound_pipeline_visuals() -> void:
	for pipeline_value: Variant in _trap_pipelines.values():
		if not is_instance_valid(pipeline_value):
			continue
		(pipeline_value as PhaseCausalPipeline).clear_boss_symbol()


# Returns the retained universe matching one Boss side identifier.
func _world_for_side(side: int) -> PhaseWorldSide:
	return _lu_world if side == EntangledEntity.Side.LU_HENG else _xing_world


# Identifies only the explicit authored Boss link catalog.
func _is_boss_link(link_id: StringName) -> bool:
	return PhaseBossController.ARMOR_LINKS.has(link_id) or PhaseBossController.TRAP_LINKS.has(link_id) or link_id == PhaseBossController.FINAL_POWER_LINK


# Converts one explicit armor link into its fixed visual plate index.
func _armor_index(link_id: StringName) -> int:
	match link_id:
		&"boss_armor_1":
			return 1
		&"boss_armor_2":
			return 2
		&"boss_armor_3":
			return 3
		_:
			return 0


# Converts one structured trap id into its fixed shared-symbol index.
func _trap_index(trap_id: StringName) -> int:
	return PhaseBossController.TRAP_ORDER.find(trap_id) + 1


# Reads the actual cross-space delay from the authored trap pipeline output.
func _trap_line_delay(trap_id: StringName) -> float:
	var pipeline := _trap_pipelines.get(trap_id) as PhaseCausalPipeline
	if pipeline == null:
		return EntanglementBus.base_delay
	var result := pipeline.evaluate_pipeline(true, false)
	return EntanglementBus.base_delay + float(result.get_output(trap_id).get("delay", 0.0))


# Reads the accessibility preference in isolated tests and full game scenes.
func _read_low_flash_mode() -> bool:
	return bool(SettingsModule.instance.get_value("low_flash_mode", false)) if SettingsModule.instance != null else false


# Applies stable pulses to all active Boss cues after a live setting change.
func _on_setting_changed(key: String, value: Variant) -> void:
	if key != "low_flash_mode":
		return
	_low_flash_mode = bool(value)
	if _avatar != null:
		_avatar.set_low_flash_mode(_low_flash_mode)
