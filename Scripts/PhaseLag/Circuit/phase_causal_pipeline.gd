class_name PhaseCausalPipeline
extends Node2D
## Authored world-space causal pipeline that produces one deterministic CircuitRunPlan.

signal breaker_changed(closed: bool)
signal output_state_changed(output_id: StringName, powered: bool, delay: float, event: EntanglementEvent)
signal short_circuit_detected(diagnostics: PackedStringArray)
signal run_started(run_id: StringName, end_time: float)
signal run_finished(run_id: StringName)
signal run_rejected(diagnostics: PackedStringArray)
signal run_cancelled(run_id: StringName)
signal held_part_changed(definition: CircuitPartDefinition)
signal focus_started
signal focus_ended
signal part_picked_up
signal part_rotated
signal part_placed

const PORT_UP: int = CircuitPartDefinition.PORT_UP
const PORT_RIGHT: int = CircuitPartDefinition.PORT_RIGHT
const PORT_DOWN: int = CircuitPartDefinition.PORT_DOWN
const PORT_LEFT: int = CircuitPartDefinition.PORT_LEFT
const DIRECTION_BITS: Array[int] = [PORT_UP, PORT_RIGHT, PORT_DOWN, PORT_LEFT]
const FOCUS_BREAKER_ID: StringName = &"__breaker__"

@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export var allow_timer_chaining: bool = false
@export var interaction_enabled: bool = true
@export_range(80.0, 320.0, 1.0, "suffix:px") var interaction_radius: float = 220.0
@export_range(0.1, 12.0, 0.1, "suffix:s") var source_pulse_seconds: float = 4.0
@export_range(0.0, 3.0, 0.1, "suffix:s") var preparation_seconds: float = 0.35
@export var commit_memory_on_start: bool = false
@export var repeatable_runs: bool = false
@export var expected_output_delays: Dictionary[StringName, float] = {}

var breaker_closed: bool = false
var _run_requires_reset: bool = false
var _slots: Dictionary[StringName, PhasePipelineSocket] = {}
var _initial_state: Dictionary[StringName, Dictionary] = {}
var _initial_external_sources: Dictionary[StringName, bool] = {}
var _initial_interference_sources: Dictionary[StringName, StringName] = {}
var _external_source_states: Dictionary[StringName, bool] = {}
var _interference_sources: Dictionary[StringName, StringName] = {}
var _last_output_states: Dictionary[StringName, bool] = {}
var _held_part: Dictionary = {}
var _run_plan: CircuitRunPlan
var _run_id: StringName = &""
var _run_start_time: float = 0.0
var _run_dispatch_index: int = 0
var _run_serial: int = 0
var _player_focus_active: bool = false
var _focused_target_id: StringName = &""
var _focus_player_position: Vector2 = Vector2.ZERO
var _breaker_link_socket_id: StringName = &""
var _boss_symbol_tween: Tween

@onready var slots_root: Node2D = $Slots
@onready var conduits: Node2D = $Conduits
@onready var flow_markers: Node2D = $FlowMarkers
@onready var breaker_interaction_point: Marker2D = $Breaker/InteractionPoint
@onready var breaker_terminal: Sprite2D = $Breaker/Terminal
@onready var breaker_indicator: Polygon2D = $Breaker/Indicator
@onready var breaker_outline_material: ShaderMaterial = breaker_terminal.material as ShaderMaterial
@onready var interaction_prompt: WorldInteractionPrompt = $Breaker/InteractionPrompt
@onready var held_preview: Node2D = $HeldPreview
@onready var held_preview_sprite: Sprite2D = $HeldPreview/Sprite
@onready var held_orientation: Label = $HeldPreview/Orientation
@onready var run_light: PointLight2D = $RunLight
@onready var run_particles: GPUParticles2D = $RunParticles
@onready var run_audio: AudioStreamPlayer2D = $RunAudio
@onready var pickup_audio: AudioStreamPlayer2D = $PickupAudio
@onready var place_audio: AudioStreamPlayer2D = $PlaceAudio
@onready var rotate_audio: AudioStreamPlayer2D = $RotateAudio
@onready var boss_symbol: Node2D = $BossSymbol
@onready var calibration_ring: Line2D = $BossSymbol/CalibrationRing
@onready var rune_one: Polygon2D = $BossSymbol/RuneOne
@onready var rune_two: Polygon2D = $BossSymbol/RuneTwo
@onready var rune_three: Polygon2D = $BossSymbol/RuneThree


# Indexes the authored socket graph and prepares world-space feedback.
func _ready() -> void:
	_index_slots()
	_validate_connections()
	_update_breaker_visual()
	_update_held_preview()
	_update_conduit_flow(false)
	clear_player_proximity()
	clear_boss_symbol()
	call_deferred("_capture_initial_state")


# Dispatches due run-plan edges against the shared deterministic causality clock.
func _process(_delta: float) -> void:
	advance_run()


# Builds one immutable schedule from the current physical module arrangement.
func build_run_plan(commit_memory: bool = false) -> CircuitRunPlan:
	var plan := CircuitRunPlan.new()
	var evaluation := evaluate_pipeline(true, commit_memory)
	if not evaluation.valid:
		for diagnostic: String in evaluation.diagnostics:
			plan.reject(diagnostic)
		return plan
	var output_count := 0
	for socket: PhasePipelineSocket in _slots.values():
		var part := socket.part
		if part.definition == null or part.definition.part_type != CircuitPartDefinition.PartType.OUTPUT:
			continue
		var record := evaluation.get_output(part.output_id)
		if not bool(record.get("reachable", false)):
			plan.reject("输出 %s 未接通" % part.output_id)
			continue
		if not bool(record.get("powered", false)):
			plan.reject("输出 %s 未获得有效脉冲" % part.output_id)
			continue
		output_count += 1
		var module_delay := float(record.get("delay", 0.0))
		if expected_output_delays.has(part.output_id):
			var expected_delay := expected_output_delays[part.output_id]
			if not is_equal_approx(module_delay, expected_delay):
				plan.reject("输出 %s 需要 %.0fs，当前为 %.0fs" % [part.output_id, expected_delay, module_delay])
				continue
		var remote_output := not part.output_link_id.is_empty()
		var transfer_delay := module_delay + (EntanglementBus.base_delay if remote_output else 0.0)
		var interval := CircuitInterval.new(transfer_delay, transfer_delay + source_pulse_seconds)
		plan.set_interval(part.output_id, interval)
		var opening_send := preparation_seconds if remote_output else preparation_seconds + interval.start_time
		var closing_send := preparation_seconds + source_pulse_seconds if remote_output else preparation_seconds + interval.end_time
		plan.add_transition(CircuitOutputTransition.new(
			part.output_id,
			true,
			preparation_seconds + interval.start_time,
			opening_send,
			transfer_delay if remote_output else 0.0,
			part.output_link_id,
			part.output_event_type
		))
		plan.add_transition(CircuitOutputTransition.new(
			part.output_id,
			false,
			preparation_seconds + interval.end_time,
			closing_send,
			transfer_delay if remote_output else 0.0,
			part.output_link_id,
			part.output_event_type
		))
	if output_count == 0:
		plan.reject("实体管线没有可运行的输出")
	return plan


# Evaluates physical ports, directed modules, gates, memory, and accumulated delay.
func evaluate_pipeline(source_powered: bool, commit_memory: bool = false) -> CircuitEvaluation:
	var result := CircuitEvaluation.new()
	var effective_source_powered := source_powered
	match _resolve_interference_mode():
		&"force_on":
			effective_source_powered = true
		&"cut", &"jam_off":
			effective_source_powered = false
		&"invert":
			effective_source_powered = not effective_source_powered
	var queue: Array[Dictionary] = []
	var arrivals: Dictionary[StringName, Dictionary] = {}
	var and_inputs: Dictionary[StringName, Dictionary] = {}
	var and_emitted: Dictionary[StringName, bool] = {}
	for socket: PhasePipelineSocket in _slots.values():
		var part := socket.part
		part.set_powered(false)
		if part.definition != null and part.definition.part_type == CircuitPartDefinition.PartType.GENERATOR:
			var generator_powered := effective_source_powered
			if not part.source_id.is_empty():
				generator_powered = effective_source_powered and bool(_external_source_states.get(part.source_id, false))
			queue.append({
				"socket_id": socket.socket_id,
				"enter": 0,
				"powered": generator_powered,
				"delay": 0.0,
				"timers": 0,
			})
	while not queue.is_empty() and result.valid:
		var signal_state: Dictionary = queue.pop_front()
		_process_signal(signal_state, queue, arrivals, and_inputs, and_emitted, result, commit_memory)
	if not effective_source_powered:
		for output_id: StringName in result.outputs:
			result.outputs[output_id]["powered"] = false
	return result


# Starts one valid immutable run and locks further module editing until reset.
func start_run() -> bool:
	if breaker_closed or _run_requires_reset or not _held_part.is_empty():
		return false
	var plan := build_run_plan(commit_memory_on_start)
	if not plan.valid:
		short_circuit_detected.emit(plan.diagnostics)
		run_rejected.emit(plan.diagnostics)
		_flash_breaker_error()
		return false
	_run_serial += 1
	_run_id = StringName("%s:%d" % [get_path(), _run_serial])
	_run_plan = plan
	_run_start_time = EntanglementBus.current_time
	_run_dispatch_index = 0
	breaker_closed = true
	_last_output_states.clear()
	_update_breaker_visual()
	_update_conduit_flow(true)
	_play_run_started_feedback()
	breaker_changed.emit(true)
	run_started.emit(_run_id, _run_start_time + plan.end_time)
	advance_run()
	return true


# Dispatches every due transition and restores repeatable authored breakers after the final edge.
func advance_run() -> void:
	if not breaker_closed or _run_plan == null:
		return
	var elapsed := maxf(EntanglementBus.current_time - _run_start_time, 0.0)
	while _run_dispatch_index < _run_plan.transitions.size():
		var transition := _run_plan.transitions[_run_dispatch_index] as CircuitOutputTransition
		if transition.send_time > elapsed and not is_equal_approx(transition.send_time, elapsed):
			break
		_dispatch_transition(transition)
		_run_dispatch_index += 1
	if elapsed < _run_plan.end_time and not is_equal_approx(elapsed, _run_plan.end_time):
		return
	var finished_run_id := _run_id
	breaker_closed = false
	_run_requires_reset = not repeatable_runs
	_run_plan = null
	_run_id = &""
	_update_breaker_visual()
	_update_conduit_flow(false)
	breaker_changed.emit(false)
	run_finished.emit(finished_run_id)


# Cancels unsent and in-flight edges owned by the current pipeline attempt.
func cancel_run() -> void:
	if _run_id.is_empty() and _run_plan == null:
		return
	var cancelled_run_id := _run_id
	EntanglementBus.cancel_run(cancelled_run_id)
	_run_plan = null
	_run_id = &""
	_run_dispatch_index = 0
	breaker_closed = false
	_update_breaker_visual()
	_update_conduit_flow(false)
	breaker_changed.emit(false)
	run_cancelled.emit(cancelled_run_id)


# Restores authored modules, memory, source states, and optional global event state.
func reset_pipeline(clear_in_flight_events: bool = false) -> void:
	end_player_focus()
	cancel_run()
	breaker_closed = false
	_run_requires_reset = false
	_external_source_states = _initial_external_sources.duplicate()
	_interference_sources = _initial_interference_sources.duplicate()
	for socket_id: StringName in _slots:
		var socket := _slots[socket_id]
		var snapshot: Dictionary = _initial_state.get(socket_id, {})
		var definition := snapshot.get("definition") as CircuitPartDefinition
		if definition == null:
			socket.clear_part()
		else:
			socket.set_part(
				definition,
				int(snapshot.get("rotation", 0)),
				bool(snapshot.get("fixed", false)),
				StringName(snapshot.get("source_id", &"")),
				StringName(snapshot.get("output_id", &"")),
				StringName(snapshot.get("output_link_id", &"")),
				StringName(snapshot.get("output_event_type", EntanglementBus.POWER_CHANGED))
			)
		socket.part.memory_latched = false
		socket.part.set_powered(false)
	_held_part.clear()
	_last_output_states.clear()
	_update_breaker_visual()
	_update_conduit_flow(false)
	_update_held_preview()
	clear_player_proximity()
	if clear_in_flight_events:
		EntanglementBus.reset_queue(true)


# Reports whether this consumed one-shot pipeline now needs a room reset.
func needs_reset() -> bool:
	return _run_requires_reset


# Enables or disables the authored mechanism without hiding its world context.
func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	modulate = Color.WHITE if value else Color(0.48, 0.56, 0.58, 0.72)
	if not value:
		clear_player_proximity()


# Reports whether Lu Heng may operate this physical pipeline now.
func is_interaction_enabled() -> bool:
	return interaction_enabled


# Returns the authored breaker-entry distance for compatibility callers.
func get_nearest_interaction_distance(player_position: Vector2) -> float:
	return get_focus_entry_distance(player_position)


# Enters world-space maintenance focus without operating the selected device.
func begin_player_focus(player_position: Vector2) -> bool:
	if not interaction_enabled or breaker_closed or _run_requires_reset:
		return false
	if get_focus_entry_distance(player_position) > interaction_radius:
		return false
	_player_focus_active = true
	_focus_player_position = player_position
	var initial_target := _find_nearest_socket(player_position, not _held_part.is_empty())
	var initial_socket := initial_target.get("socket") as PhasePipelineSocket
	_focused_target_id = initial_socket.socket_id if initial_socket != null else FOCUS_BREAKER_ID
	_refresh_focus_feedback()
	interaction_prompt.show_prompt("WASD 选择 · J 操作 · K 旋转 · L 退出")
	focus_started.emit()
	return true


# Moves selection through authored conduit neighbours and the virtual breaker edge.
func move_player_focus(direction: Vector2i) -> bool:
	if not _player_focus_active or direction == Vector2i.ZERO:
		return false
	var cardinal := _cardinalize_direction(direction)
	if cardinal == Vector2i.ZERO:
		return false
	var current_position := _get_focus_target_position(_focused_target_id)
	var best_target: Dictionary = {}
	var best_perpendicular := INF
	var best_distance := INF
	var best_id := ""
	for candidate: Dictionary in _get_focus_navigation_candidates():
		var candidate_position: Vector2 = candidate.get("position", current_position)
		var delta := candidate_position - current_position
		var direction_vector := Vector2(cardinal)
		if delta.dot(direction_vector) <= 0.5:
			continue
		var perpendicular := absf(delta.cross(direction_vector))
		var distance := delta.length()
		var candidate_id := str(candidate.get("id", &""))
		if not _is_better_focus_candidate(
				perpendicular,
				distance,
				candidate_id,
				best_perpendicular,
				best_distance,
				best_id
			):
			continue
		best_target = candidate
		best_perpendicular = perpendicular
		best_distance = distance
		best_id = candidate_id
	if best_target.is_empty():
		return false
	_focused_target_id = StringName(best_target.get("id", &""))
	_refresh_focus_feedback()
	return true


# Leaves maintenance focus while preserving any carried physical module.
func end_player_focus() -> void:
	var was_active := _player_focus_active
	_player_focus_active = false
	_focused_target_id = &""
	_clear_outline_feedback()
	_update_held_preview(_focus_player_position)
	interaction_prompt.hide_prompt()
	if was_active:
		focus_ended.emit()


# Performs J only on the explicitly focused socket or breaker.
func primary_action_on_focused_target() -> bool:
	if not _player_focus_active or not interaction_enabled or breaker_closed or _run_requires_reset:
		return false
	if _focused_target_id == FOCUS_BREAKER_ID:
		var started := start_run()
		if started:
			end_player_focus()
		return started
	var socket: PhasePipelineSocket = _slots.get(_focused_target_id)
	if socket == null:
		return false
	return _primary_action_on_socket(socket)


# Performs K on the carried part or explicitly focused movable socket.
func secondary_action_on_focused_target() -> bool:
	if not _player_focus_active or not interaction_enabled or breaker_closed or _run_requires_reset:
		return false
	if not _held_part.is_empty():
		_held_part["rotation"] = posmod(int(_held_part.get("rotation", 0)) + 1, 4)
		_update_held_preview(_focus_player_position)
		rotate_audio.pitch_scale = 1.0
		rotate_audio.play()
		part_rotated.emit()
		return true
	if _focused_target_id == FOCUS_BREAKER_ID:
		_play_focus_reject()
		return false
	var socket: PhasePipelineSocket = _slots.get(_focused_target_id)
	if socket == null or not socket.part.rotate_clockwise():
		_play_focus_reject()
		return false
	rotate_audio.pitch_scale = 1.0
	rotate_audio.play()
	part_rotated.emit()
	_refresh_focus_feedback()
	return true


# Reports whether this pipeline currently owns world-space maintenance focus.
func has_player_focus() -> bool:
	return _player_focus_active


# Measures entry strictly from the authored breaker interaction marker.
func get_focus_entry_distance(player_position: Vector2) -> float:
	if not interaction_enabled or breaker_closed or _run_requires_reset:
		return INF
	return player_position.distance_to(breaker_interaction_point.global_position)


# Keeps the legacy proximity entry point limited to an already active focus.
func primary_action_at(player_position: Vector2) -> bool:
	_focus_player_position = player_position
	return primary_action_on_focused_target()


# Keeps the legacy rotation entry point limited to an already active focus.
func secondary_action_at(player_position: Vector2) -> bool:
	_focus_player_position = player_position
	return secondary_action_on_focused_target()


# Reports whether this pipeline currently owns Lu Heng's carried module preview.
func has_held_part() -> bool:
	return not _held_part.is_empty()


# Previews whether the current physical layout reaches every authored output.
func preview_connection_state() -> bool:
	if breaker_closed or _run_requires_reset:
		return false
	var plan := build_run_plan()
	_update_conduit_flow(plan.valid)
	if plan.valid:
		return true
	var broken_marker := _find_first_broken_conduit_marker()
	if broken_marker != null:
		broken_marker.color = Color(1.0, 0.48, 0.16, 0.98)
	return false


# Updates authored outlines and the held-module preview only near this player.
func update_player_proximity(player_position: Vector2, max_range: float) -> void:
	if not interaction_enabled or max_range <= 0.0:
		clear_player_proximity()
		return
	_focus_player_position = player_position
	if _player_focus_active:
		_refresh_focus_feedback()
		return
	_clear_outline_feedback()
	var breaker_nearby := get_focus_entry_distance(player_position) <= max_range
	breaker_outline_material.set_shader_parameter("outline_strength", 0.72 if breaker_nearby else 0.0)
	if breaker_nearby:
		interaction_prompt.show_prompt("J 进入维护焦点")
	else:
		interaction_prompt.hide_prompt()
	_update_held_preview(player_position)


# Clears temporary proximity feedback without mutating the physical pipeline.
func clear_player_proximity() -> void:
	var was_active := _player_focus_active
	_player_focus_active = false
	_focused_target_id = &""
	_focus_player_position = Vector2.ZERO
	_clear_outline_feedback()
	held_preview.visible = false
	interaction_prompt.hide_prompt()
	if was_active:
		focus_ended.emit()


# Updates one named physical generator source for the next immutable snapshot.
func set_external_source(source_id: StringName, powered: bool) -> void:
	if source_id.is_empty():
		push_error("PhaseCausalPipeline.set_external_source requires a non-empty source id")
		return
	_external_source_states[source_id] = powered


# Returns one named physical source state for authored room mechanisms.
func get_external_source(source_id: StringName) -> bool:
	return bool(_external_source_states.get(source_id, false))


# Adds or clears one named parasite override for the next immutable snapshot.
func set_phase_interference_source(source_id: StringName, active: bool, mode: StringName = &"cut") -> void:
	if source_id.is_empty():
		push_error("PhaseCausalPipeline.set_phase_interference_source requires a non-empty source id")
		return
	if active:
		_interference_sources[source_id] = mode if not mode.is_empty() else &"cut"
	else:
		_interference_sources.erase(source_id)


# Reports whether one authored interference source still affects this pipeline.
func is_phase_interference_source_active(source_id: StringName) -> bool:
	return _interference_sources.has(source_id)


# Shows one of the three shared nonverbal Boss trap symbols above this mechanism.
func set_boss_symbol(index: int, value: bool) -> void:
	boss_symbol.visible = value
	rune_one.visible = value and index == 1
	rune_two.visible = value and index == 2
	rune_three.visible = value and index == 3
	if not value:
		clear_boss_symbol()


# Shrinks the authored calibration ring toward the local send center.
func begin_boss_calibration(index: int, send_center_time: float) -> void:
	set_boss_symbol(index, true)
	if _boss_symbol_tween != null and _boss_symbol_tween.is_valid():
		_boss_symbol_tween.kill()
	calibration_ring.scale = Vector2(1.75, 1.75)
	calibration_ring.modulate = Color(0.42, 0.98, 0.9, 0.9)
	var duration := maxf(send_center_time - EntanglementBus.current_time, 0.05)
	_boss_symbol_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_boss_symbol_tween.tween_property(calibration_ring, ^"scale", Vector2.ONE, duration)


# Locks the authored ring on a legal send or fractures it on a mistimed send.
func lock_boss_calibration(success: bool) -> void:
	if _boss_symbol_tween != null and _boss_symbol_tween.is_valid():
		_boss_symbol_tween.kill()
	calibration_ring.scale = Vector2.ONE
	calibration_ring.modulate = Color(0.62, 1.0, 0.94, 1.0) if success else Color(1.0, 0.25, 0.16, 0.95)


# Resolves one Boss calibration marker after its delayed device event arrives.
func resolve_boss_calibration(success: bool) -> void:
	if _boss_symbol_tween != null and _boss_symbol_tween.is_valid():
		_boss_symbol_tween.kill()
	_boss_symbol_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if success:
		_boss_symbol_tween.parallel().tween_property(boss_symbol, ^"scale", Vector2(1.25, 1.25), 0.16)
		_boss_symbol_tween.parallel().tween_property(boss_symbol, ^"modulate:a", 0.18, 0.24)
	else:
		_boss_symbol_tween.parallel().tween_property(calibration_ring, ^"scale", Vector2(1.5, 0.45), 0.24)
		_boss_symbol_tween.parallel().tween_property(calibration_ring, ^"modulate:a", 0.12, 0.24)
	_boss_symbol_tween.tween_callback(clear_boss_symbol)


# Clears the optional Boss symbol without changing gameplay state.
func clear_boss_symbol() -> void:
	if _boss_symbol_tween != null and _boss_symbol_tween.is_valid():
		_boss_symbol_tween.kill()
	boss_symbol.visible = false
	boss_symbol.scale = Vector2.ONE
	boss_symbol.modulate = Color.WHITE
	calibration_ring.scale = Vector2.ONE
	calibration_ring.modulate = Color.WHITE


# Captures the post-ready authored state after sibling relays apply stable sources.
func _capture_initial_state() -> void:
	_initial_state.clear()
	for socket_id: StringName in _slots:
		_initial_state[socket_id] = _snapshot_part(_slots[socket_id].part)
	_initial_external_sources = _external_source_states.duplicate()
	_initial_interference_sources = _interference_sources.duplicate()


# Stores one module's replaceable state for carrying and deterministic reset.
func _snapshot_part(part: CircuitPart) -> Dictionary:
	return {
		"definition": part.definition,
		"rotation": part.rotation_quarters,
		"fixed": part.fixed,
		"source_id": part.source_id,
		"output_id": part.output_id,
		"output_link_id": part.output_link_id,
		"output_event_type": part.output_event_type,
	}


# Indexes enabled authored slots by their stable semantic identifiers.
func _index_slots() -> void:
	_slots.clear()
	for child: Node in slots_root.get_children():
		var socket := child as PhasePipelineSocket
		if socket == null:
			push_error("PhaseCausalPipeline requires only PhasePipelineSocket children under Slots")
			continue
		if not socket.enabled:
			continue
		if socket.socket_id.is_empty() or _slots.has(socket.socket_id):
			push_error("PhaseCausalPipeline has an empty or duplicate socket id '%s'" % socket.socket_id)
			continue
		_slots[socket.socket_id] = socket
	_breaker_link_socket_id = _find_breaker_link_socket_id()


# Validates every authored conduit as a reciprocal axis-aligned connection.
func _validate_connections() -> void:
	for socket: PhasePipelineSocket in _slots.values():
		for connected_id: StringName in socket.connected_socket_ids:
			var other: PhasePipelineSocket = _slots.get(connected_id)
			if other == null:
				push_error("Pipeline socket '%s' references missing socket '%s'" % [socket.socket_id, connected_id])
				continue
			if not other.connected_socket_ids.has(socket.socket_id):
				push_error("Pipeline conduit '%s' <-> '%s' must be reciprocal" % [socket.socket_id, connected_id])
			if _direction_bit_between(socket, other) == 0:
				push_error("Pipeline conduit '%s' <-> '%s' must be axis aligned" % [socket.socket_id, connected_id])


# Finds the nearest movable occupied socket or legal empty placement socket.
func _find_nearest_socket(player_position: Vector2, needs_empty: bool) -> Dictionary:
	var result: Dictionary = {}
	var nearest_distance := INF
	var nearest_id := ""
	for socket: PhasePipelineSocket in _slots.values():
		var actionable := false
		if needs_empty:
			actionable = socket.part.definition == null and socket.can_accept(_held_part.get("definition") as CircuitPartDefinition)
		else:
			actionable = socket.part.definition != null and not socket.part.fixed
		if not actionable:
			continue
		var distance := player_position.distance_to(socket.get_interaction_position())
		var candidate_id := str(socket.socket_id)
		if distance < nearest_distance - 0.01 or (is_equal_approx(distance, nearest_distance) and candidate_id < nearest_id):
			nearest_distance = distance
			nearest_id = candidate_id
			result = {"kind": &"socket", "socket": socket, "distance": distance}
	return result


# Applies pickup or placement to one explicitly focused authored socket.
func _primary_action_on_socket(socket: PhasePipelineSocket) -> bool:
	if _held_part.is_empty():
		if socket.part.definition == null or socket.part.fixed:
			_play_focus_reject()
			return false
		_held_part = _snapshot_part(socket.part)
		socket.clear_part()
		pickup_audio.play()
		part_picked_up.emit()
	else:
		var definition := _held_part.get("definition") as CircuitPartDefinition
		if socket.part.definition != null or not socket.can_accept(definition):
			_play_focus_reject()
			return false
		socket.set_part(
			definition,
			int(_held_part.get("rotation", 0)),
			false,
			StringName(_held_part.get("source_id", &"")),
			StringName(_held_part.get("output_id", &"")),
			StringName(_held_part.get("output_link_id", &"")),
			StringName(_held_part.get("output_event_type", EntanglementBus.POWER_CHANGED))
		)
		_held_part.clear()
		place_audio.play()
		part_placed.emit()
	_update_held_preview(_focus_player_position)
	held_part_changed.emit(_held_part.get("definition") as CircuitPartDefinition)
	_refresh_focus_feedback()
	return true


# Shows the focused topology through pre-bound socket and part outline materials.
func _refresh_focus_feedback() -> void:
	if not _player_focus_active:
		return
	var focused_socket: PhasePipelineSocket = _slots.get(_focused_target_id)
	var held_definition := _held_part.get("definition") as CircuitPartDefinition
	for socket: PhasePipelineSocket in _slots.values():
		var selected := socket == focused_socket
		var fixed_landmark := socket.part.definition != null and socket.part.fixed
		var legal := held_definition != null and socket.part.definition == null and socket.can_accept(held_definition)
		var pickup := held_definition == null and socket.part.definition != null and not socket.part.fixed
		var invalid := selected and not fixed_landmark and not legal and not pickup
		var nearby := selected or fixed_landmark or legal or pickup
		socket.set_feedback(nearby, legal, selected, fixed_landmark, invalid)
	var breaker_selected := _focused_target_id == FOCUS_BREAKER_ID
	breaker_outline_material.set_shader_parameter("outline_color", Color(0.36, 1.0, 0.84, 1.0))
	breaker_outline_material.set_shader_parameter("outline_strength", 1.0 if breaker_selected else 0.32)
	_update_held_preview(_focus_player_position)


# Clears transient topology emphasis while leaving authored base outlines intact.
func _clear_outline_feedback() -> void:
	breaker_outline_material.set_shader_parameter("outline_strength", 0.0)
	for socket: PhasePipelineSocket in _slots.values():
		socket.set_feedback(false, false, false)


# Plays a short low-pitch authored tool sound for fixed or illegal operations.
func _play_focus_reject() -> void:
	rotate_audio.pitch_scale = 0.72
	rotate_audio.play()


# Reduces mixed analogue input to one stable cardinal navigation direction.
func _cardinalize_direction(direction: Vector2i) -> Vector2i:
	if direction.x == 0:
		return Vector2i(0, signi(direction.y))
	if direction.y == 0:
		return Vector2i(signi(direction.x), 0)
	if absi(direction.x) >= absi(direction.y):
		return Vector2i(signi(direction.x), 0)
	return Vector2i(0, signi(direction.y))


# Returns the world position of a socket or the virtual breaker target.
func _get_focus_target_position(target_id: StringName) -> Vector2:
	if target_id == FOCUS_BREAKER_ID:
		return breaker_interaction_point.global_position
	var socket: PhasePipelineSocket = _slots.get(target_id)
	return socket.get_interaction_position() if socket != null else breaker_interaction_point.global_position


# Lists only authored graph neighbours plus the breaker's single virtual edge.
func _get_focus_navigation_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if _focused_target_id == FOCUS_BREAKER_ID:
		var linked_socket: PhasePipelineSocket = _slots.get(_breaker_link_socket_id)
		if linked_socket != null:
			candidates.append({
				"id": linked_socket.socket_id,
				"position": linked_socket.get_interaction_position(),
			})
		return candidates
	var current_socket: PhasePipelineSocket = _slots.get(_focused_target_id)
	if current_socket == null:
		return candidates
	for connected_id: StringName in current_socket.connected_socket_ids:
		var connected_socket: PhasePipelineSocket = _slots.get(connected_id)
		if connected_socket == null:
			continue
		candidates.append({
			"id": connected_socket.socket_id,
			"position": connected_socket.get_interaction_position(),
		})
	if current_socket.socket_id == _breaker_link_socket_id:
		candidates.append({
			"id": FOCUS_BREAKER_ID,
			"position": breaker_interaction_point.global_position,
		})
	return candidates


# Orders directional candidates by perpendicular error, distance, then socket id.
func _is_better_focus_candidate(
		perpendicular: float,
		distance: float,
		candidate_id: String,
		best_perpendicular: float,
		best_distance: float,
		best_id: String
	) -> bool:
	if perpendicular < best_perpendicular - 0.01:
		return true
	if not is_equal_approx(perpendicular, best_perpendicular):
		return false
	if distance < best_distance - 0.01:
		return true
	if not is_equal_approx(distance, best_distance):
		return false
	return best_id.is_empty() or candidate_id < best_id


# Connects the breaker virtual target to the closest enabled authored socket.
func _find_breaker_link_socket_id() -> StringName:
	var nearest_id: StringName = &""
	var nearest_distance := INF
	for socket: PhasePipelineSocket in _slots.values():
		var distance := breaker_interaction_point.global_position.distance_to(socket.get_interaction_position())
		if distance < nearest_distance - 0.01 or (is_equal_approx(distance, nearest_distance) and str(socket.socket_id) < str(nearest_id)):
			nearest_distance = distance
			nearest_id = socket.socket_id
	return nearest_id


# Processes one queued signal at an authored world-space module.
func _process_signal(
		signal_state: Dictionary,
		queue: Array[Dictionary],
		arrivals: Dictionary[StringName, Dictionary],
		and_inputs: Dictionary[StringName, Dictionary],
		and_emitted: Dictionary[StringName, bool],
		result: CircuitEvaluation,
		commit_memory: bool
	) -> void:
	var socket_id := StringName(signal_state["socket_id"])
	var socket: PhasePipelineSocket = _slots.get(socket_id)
	if socket == null or socket.part.definition == null:
		return
	var part := socket.part
	var part_type := part.definition.part_type
	var enter_bit := int(signal_state["enter"])
	if part_type == CircuitPartDefinition.PartType.GENERATOR:
		if enter_bit != 0:
			result.mark_short("信号回流到实体电源 %s" % socket_id)
			return
		part.set_powered(bool(signal_state["powered"]))
		_propagate_from(socket, part.get_output_ports(), signal_state, queue)
		return
	if enter_bit == 0 or (part.get_input_ports() & enter_bit) == 0:
		return
	if part_type == CircuitPartDefinition.PartType.AND_GATE:
		_process_and_gate(socket, enter_bit, signal_state, queue, and_inputs, and_emitted, result)
		return
	var seen: Dictionary = arrivals.get(socket_id, {})
	if not seen.is_empty() and not seen.has(enter_bit):
		result.mark_short("普通导管在 %s 发生无规则合流" % socket_id)
		return
	if seen.has(enter_bit):
		return
	seen[enter_bit] = true
	arrivals[socket_id] = seen
	var powered := bool(signal_state["powered"])
	var delay := float(signal_state["delay"])
	var timers := int(signal_state["timers"])
	match part_type:
		CircuitPartDefinition.PartType.WIRE_STRAIGHT, CircuitPartDefinition.PartType.WIRE_CORNER, CircuitPartDefinition.PartType.WIRE_TEE:
			part.set_powered(powered)
			_propagate_from(socket, part.get_output_ports() & ~enter_bit, signal_state, queue)
		CircuitPartDefinition.PartType.TIMER:
			timers += 1
			if timers > 1 and not allow_timer_chaining:
				result.mark_short("当前实体管线不允许继电器串联")
				return
			part.set_powered(powered)
			var timed_state := signal_state.duplicate()
			timed_state["delay"] = delay + part.definition.delay_seconds
			timed_state["timers"] = timers
			_propagate_from(socket, part.get_output_ports(), timed_state, queue)
		CircuitPartDefinition.PartType.INVERTER:
			part.set_powered(not powered)
			var inverted_state := signal_state.duplicate()
			inverted_state["powered"] = not powered
			_propagate_from(socket, part.get_output_ports(), inverted_state, queue)
		CircuitPartDefinition.PartType.MEMORY:
			if powered and commit_memory:
				part.memory_latched = true
			var memory_powered := powered or part.memory_latched
			part.set_powered(memory_powered)
			var memory_state := signal_state.duplicate()
			memory_state["powered"] = memory_powered
			_propagate_from(socket, part.get_output_ports(), memory_state, queue)
		CircuitPartDefinition.PartType.OUTPUT:
			part.set_powered(powered)
			if part.output_id.is_empty():
				result.mark_short("实体输出 %s 缺少 output_id" % socket_id)
				return
			if result.outputs.has(part.output_id):
				result.mark_short("输出 %s 被多条导管合流" % part.output_id)
				return
			result.set_output(part.output_id, powered, delay, true)
			part.set_delay_readout(delay, true)


# Waits for both directed inputs and emits an AND result at the later arrival.
func _process_and_gate(
		socket: PhasePipelineSocket,
		enter_bit: int,
		signal_state: Dictionary,
		queue: Array[Dictionary],
		and_inputs: Dictionary[StringName, Dictionary],
		and_emitted: Dictionary[StringName, bool],
		result: CircuitEvaluation
	) -> void:
	var states: Dictionary = and_inputs.get(socket.socket_id, {})
	if states.has(enter_bit):
		return
	states[enter_bit] = signal_state.duplicate()
	and_inputs[socket.socket_id] = states
	var required_mask := socket.part.get_input_ports()
	for bit: int in DIRECTION_BITS:
		if (required_mask & bit) != 0 and not states.has(bit):
			return
	if and_emitted.get(socket.socket_id, false):
		result.mark_short("双输入联锁 %s 收到重复合流" % socket.socket_id)
		return
	and_emitted[socket.socket_id] = true
	var powered := true
	var delay := 0.0
	var timers := 0
	for state: Dictionary in states.values():
		powered = powered and bool(state["powered"])
		delay = maxf(delay, float(state["delay"]))
		timers = maxi(timers, int(state["timers"]))
	socket.part.set_powered(powered)
	_propagate_from(socket, socket.part.get_output_ports(), {
		"socket_id": socket.socket_id,
		"enter": 0,
		"powered": powered,
		"delay": delay,
		"timers": timers,
	}, queue)


# Queues only reciprocal, axis-aligned authored conduit neighbours with matching ports.
func _propagate_from(socket: PhasePipelineSocket, port_mask: int, signal_state: Dictionary, queue: Array[Dictionary]) -> void:
	for connected_id: StringName in socket.connected_socket_ids:
		var neighbour: PhasePipelineSocket = _slots.get(connected_id)
		if neighbour == null or neighbour.part.definition == null:
			continue
		var direction_bit := _direction_bit_between(socket, neighbour)
		if direction_bit == 0 or (port_mask & direction_bit) == 0:
			continue
		var opposite := _opposite_port(direction_bit)
		if (neighbour.part.get_ports() & opposite) == 0:
			continue
		queue.append({
			"socket_id": connected_id,
			"enter": opposite,
			"powered": bool(signal_state["powered"]),
			"delay": float(signal_state["delay"]),
			"timers": int(signal_state["timers"]),
		})


# Converts authored slot positions into the intuitive horizontal or vertical port bit.
func _direction_bit_between(from_socket: PhasePipelineSocket, to_socket: PhasePipelineSocket) -> int:
	var delta := to_socket.position - from_socket.position
	if is_zero_approx(delta.x) and is_zero_approx(delta.y):
		return 0
	if absf(delta.x) > absf(delta.y) * 2.0:
		return PORT_RIGHT if delta.x > 0.0 else PORT_LEFT
	if absf(delta.y) > absf(delta.x) * 2.0:
		return PORT_DOWN if delta.y > 0.0 else PORT_UP
	return 0


# Returns the opposite cardinal port bit for conduit traversal.
func _opposite_port(bit: int) -> int:
	match bit:
		PORT_UP:
			return PORT_DOWN
		PORT_RIGHT:
			return PORT_LEFT
		PORT_DOWN:
			return PORT_UP
		PORT_LEFT:
			return PORT_RIGHT
	return 0


# Resolves simultaneous interference deterministically with physical cuts first.
func _resolve_interference_mode() -> StringName:
	for mode: StringName in [&"cut", &"jam_off"]:
		if _interference_sources.values().has(mode):
			return mode
	if _interference_sources.values().has(&"force_on"):
		return &"force_on"
	if _interference_sources.values().has(&"invert"):
		return &"invert"
	return &""


# Sends one remote edge or applies one same-space edge at its scheduled moment.
func _dispatch_transition(transition: CircuitOutputTransition) -> void:
	_last_output_states[transition.output_id] = transition.value
	var event: EntanglementEvent = null
	if not transition.link_id.is_empty():
		event = EntanglementBus.emit_event(
			transition.link_id,
			transition.event_type,
			{"value": transition.value, "output_id": transition.output_id},
			side,
			transition.transfer_delay,
			_run_id,
			_run_start_time + transition.send_time
		)
		if event != null and event.arrival_time <= EntanglementBus.current_time:
			EntanglementBus.advance(0.0)
	output_state_changed.emit(transition.output_id, transition.value, transition.transfer_delay, event)


# Updates the authored breaker light from editable, running, and consumed states.
func _update_breaker_visual() -> void:
	if not is_node_ready():
		return
	if breaker_closed:
		breaker_indicator.color = Color(0.32, 1.0, 0.68, 1.0)
	elif _run_requires_reset:
		breaker_indicator.color = Color(0.86, 0.48, 0.18, 0.92)
	else:
		breaker_indicator.color = Color(0.28, 0.42, 0.44, 0.82)


# Places the carried-module texture and orientation above Lu Heng's world position.
func _update_held_preview(player_position: Vector2 = Vector2.INF) -> void:
	if not is_node_ready():
		return
	held_preview.visible = not _held_part.is_empty()
	if _held_part.is_empty():
		return
	var definition := _held_part.get("definition") as CircuitPartDefinition
	held_preview_sprite.texture = definition.visual_texture
	held_preview_sprite.scale = definition.visual_scale * 1.15
	held_preview_sprite.position = definition.visual_offset
	held_preview_sprite.rotation = float(int(_held_part.get("rotation", 0))) * PI * 0.5
	held_orientation.text = "%d°" % (int(_held_part.get("rotation", 0)) * 90)
	if player_position != Vector2.INF:
		held_preview.global_position = player_position + Vector2(0.0, -138.0)


# Plays the authored one-shot feedback when a valid pipeline run begins.
func _play_run_started_feedback() -> void:
	run_audio.play()
	run_particles.restart()
	run_particles.emitting = true
	run_light.energy = 0.7
	var tween := create_tween()
	tween.tween_property(run_light, ^"energy", 0.15, 0.34)


# Gives the authored conduit chevrons a weak idle direction or a continuous valid signal.
func _update_conduit_flow(active: bool) -> void:
	if not is_node_ready():
		return
	for index in flow_markers.get_child_count():
		var marker := flow_markers.get_child(index) as Polygon2D
		var conduit: Line2D = conduits.get_child(index) as Line2D if index < conduits.get_child_count() else null
		if marker == null:
			continue
		marker.visible = conduit != null and conduit.visible
		if marker.visible and conduit.points.size() >= 2:
			var start := to_local(conduits.to_global(conduit.points[0]))
			var finish := to_local(conduits.to_global(conduit.points[conduit.points.size() - 1]))
			marker.position = (start + finish) * 0.5
			marker.rotation = (finish - start).angle()
		marker.color = Color(0.34, 1.0, 0.78, 0.9) if active else Color(0.34, 0.66, 0.64, 0.38)


# Locates the first authored conduit whose two endpoint ports do not meet.
func _find_first_broken_conduit_marker() -> Polygon2D:
	for index in mini(conduits.get_child_count(), flow_markers.get_child_count()):
		var conduit := conduits.get_child(index) as Line2D
		var marker := flow_markers.get_child(index) as Polygon2D
		if conduit == null or marker == null or not conduit.visible or conduit.points.size() < 2:
			continue
		var first_socket := _find_socket_at_local_position(to_local(conduits.to_global(conduit.points[0])))
		var second_socket := _find_socket_at_local_position(to_local(conduits.to_global(conduit.points[conduit.points.size() - 1])))
		if first_socket == null or second_socket == null:
			continue
		var direction := _direction_bit_between(first_socket, second_socket)
		if direction == 0:
			continue
		if (first_socket.part.get_ports() & direction) == 0 or (second_socket.part.get_ports() & _opposite_port(direction)) == 0:
			return marker
	return null


# Finds the socket whose authored plate sits at one conduit endpoint.
func _find_socket_at_local_position(local_position: Vector2) -> PhasePipelineSocket:
	for socket: PhasePipelineSocket in _slots.values():
		if to_local(socket.global_position).distance_to(local_position) <= 4.0:
			return socket
	return null


# Flashes the authored breaker instead of opening a modal diagnostic panel.
func _flash_breaker_error() -> void:
	breaker_indicator.color = Color(1.0, 0.2, 0.12, 1.0)
	var broken_marker := _find_first_broken_conduit_marker()
	if broken_marker != null:
		broken_marker.color = Color(1.0, 0.48, 0.16, 0.98)
	var tween := create_tween()
	tween.tween_property(breaker_indicator, ^"color", Color(0.28, 0.42, 0.44, 0.82), 0.3)
	if broken_marker != null:
		tween.parallel().tween_property(broken_marker, ^"color", Color(0.34, 0.66, 0.64, 0.38), 0.3)
