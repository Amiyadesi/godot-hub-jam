class_name PhaseBossController
extends Node
## Single-body Boss state machine driven by authored parasites, physical pipelines, and one heavy-strike window.

signal round_started(round_index: int)
signal teleport_warning(target_side: int, seconds: float)
signal teleport_completed(current_side: int)
signal trap_window_opened(trap_id: StringName, center_time: float, tolerance: float)
signal trap_resolved(trap_id: StringName, success: bool)
signal final_window_changed(has_power: bool, has_core: bool, seconds_left: float)
signal break_attack_warning(target_side: int, duration: float)
signal defeated
signal failed(reason: String)

enum BossState {
	INACTIVE,
	ROUND_ONE,
	ROUND_TWO,
	ROUND_THREE,
	DEFEATED,
}

const ARMOR_LINKS: Dictionary[StringName, StringName] = {
	&"boss_armor_1": &"armor_a",
	&"boss_armor_2": &"armor_b",
	&"boss_armor_3": &"armor_c",
}
const TRAP_LINKS: Dictionary[StringName, StringName] = {
	&"boss_trap_clamp": &"clamp",
}
const TRAP_ORDER: Array[StringName] = [&"clamp"]
const FINAL_POWER_LINK: StringName = &"boss_final_power"
const BREAK_WARNING_SECONDS: float = 4.0

var state: BossState = BossState.INACTIVE
var current_side: int = EntangledEntity.Side.LU_HENG
var active: bool = false

var _lu_world: PhaseWorldSide
var _xing_world: PhaseWorldSide
var _lu_viewport: SubViewport
var _xing_viewport: SubViewport
var _avatar: PhaseBossAvatar
var _support: BossSupportObjective
var _boss_lu_side: PhaseRoomSide
var _boss_xing_side: PhaseRoomSide
var _trap_pipelines: Dictionary[StringName, PhaseCausalPipeline] = {}
var _trap_devices: Dictionary[StringName, PoweredDevice] = {}
var _trap_device_callbacks: Dictionary[StringName, Callable] = {}
var _final_pipeline: PhaseCausalPipeline
var _authored_room_bound: bool = false
var _teleport_target: int = EntangledEntity.Side.LU_HENG
var _teleport_countdown: float = 0.0
var _next_round_after_teleport: int = 0
var _normal_attack_timer: float = 3.0
var _break_attack_timer: float = 7.0
var _break_countdown: float = 0.0
var _round_timeout: float = 75.0
var _phase_three_teleport_timer: float = 7.0


# Advances pursuit, warnings, final-window expiry, teleports, and support timeout rules.
func _process(delta: float) -> void:
	if not active:
		return
	if state == BossState.ROUND_THREE:
		_support.tick(EntanglementBus.current_time)
		if not active:
			return
	_round_timeout -= delta
	if _round_timeout <= 0.0:
		fail_boss("关键支援超时")
		return
	if _teleport_countdown > 0.0:
		_teleport_countdown = maxf(_teleport_countdown - delta, 0.0)
		teleport_warning.emit(_teleport_target, _teleport_countdown)
		if is_zero_approx(_teleport_countdown):
			_complete_teleport()
		return
	if state == BossState.ROUND_THREE and _support.is_final_window_open():
		return
	_update_attacks(delta)
	if state == BossState.ROUND_THREE:
		_phase_three_teleport_timer -= delta
		if _phase_three_teleport_timer <= 0.0:
			_phase_three_teleport_timer = 7.0
			begin_teleport(1 - current_side)


# Injects the retained players, viewports, single body, and structured objective tracker.
func setup(
		lu_world: PhaseWorldSide,
		xing_world: PhaseWorldSide,
		lu_viewport: SubViewport,
		xing_viewport: SubViewport,
		avatar: PhaseBossAvatar,
		support: BossSupportObjective
	) -> void:
	_lu_world = lu_world
	_xing_world = xing_world
	_lu_viewport = lu_viewport
	_xing_viewport = xing_viewport
	_avatar = avatar
	_support = support
	if not _support.round_one_progress.is_connected(_on_round_one_progress):
		_support.round_one_progress.connect(_on_round_one_progress)
		_support.round_two_progress.connect(_on_round_two_progress)
		_support.trap_missed.connect(_on_trap_missed)
		_support.final_progress.connect(_on_final_progress)
		_support.final_attempt_missed.connect(_on_final_attempt_missed)
		_support.condition_complete.connect(_on_condition_complete)
	if not EntanglementBus.event_arrived.is_connected(_on_entanglement_event_arrived):
		EntanglementBus.event_arrived.connect(_on_entanglement_event_arrived)
	if not _avatar.core_struck.is_connected(_on_core_struck):
		_avatar.core_struck.connect(_on_core_struck)


# Binds the fixed authored Boss-room pipelines, clamp, parasites, and final core route.
func bind_authored_room(lu_side: PhaseRoomSide, xing_side: PhaseRoomSide) -> bool:
	unbind_authored_room()
	_boss_lu_side = lu_side
	_boss_xing_side = xing_side
	if _boss_lu_side == null or _boss_xing_side == null:
		push_error("PhaseBossController.bind_authored_room requires both authored room sides")
		_authored_room_bound = false
		return false
	_trap_pipelines = {
		&"clamp": _boss_lu_side.get_node_or_null("Mechanisms/ClampPipeline") as PhaseCausalPipeline,
	}
	_trap_devices = {
		&"clamp": _boss_xing_side.get_node_or_null("Mechanisms/MagneticClamp") as PoweredDevice,
	}
	_final_pipeline = _boss_lu_side.get_node_or_null("Mechanisms/CorePipeline") as PhaseCausalPipeline
	for trap_id: StringName in TRAP_ORDER:
		if _trap_pipelines.get(trap_id) == null or _trap_devices.get(trap_id) == null:
			push_error("PhaseBossController authored room is missing trap '%s'" % trap_id)
			_authored_room_bound = false
			return false
		var callback := _on_trap_device_arrived.bind(trap_id)
		_trap_device_callbacks[trap_id] = callback
		(_trap_devices[trap_id] as PoweredDevice).remote_event_applied.connect(callback)
	if _final_pipeline == null:
		push_error("PhaseBossController authored room is missing CorePipeline")
		_authored_room_bound = false
		return false
	_authored_room_bound = true
	_reset_authored_mechanisms()
	return true


# Releases every room-local reference before an authored Boss room is replaced or freed.
func unbind_authored_room() -> void:
	_disconnect_trap_device_callbacks()
	_boss_lu_side = null
	_boss_xing_side = null
	_trap_pipelines.clear()
	_trap_devices.clear()
	_final_pipeline = null
	_authored_room_bound = false
	active = false
	state = BossState.INACTIVE


# Reports whether the controller owns a complete live authored Boss mechanism set.
func is_authored_room_bound() -> bool:
	return _authored_room_bound


# Starts round one with the only Boss body in Lu Heng's universe.
func start_boss() -> void:
	if not _authored_room_bound:
		push_error("PhaseBossController.start_boss requires bind_authored_room first")
		return
	active = true
	state = BossState.ROUND_ONE
	current_side = EntangledEntity.Side.LU_HENG
	_round_timeout = 75.0
	_normal_attack_timer = 3.0
	_break_attack_timer = 7.0
	_break_countdown = 0.0
	_teleport_countdown = 0.0
	_reset_authored_mechanisms()
	_avatar.reparent(_lu_viewport, false)
	_avatar.position = _lu_world.get_boss_spawn_position()
	_avatar.reset_avatar()
	_support.start_round(1)
	round_started.emit(1)


# Starts one readable three-second transfer warning toward the other universe.
func begin_teleport(target_side: int, next_round: int = 0) -> void:
	if not active or _teleport_countdown > 0.0 or target_side == current_side:
		return
	_teleport_target = target_side
	_next_round_after_teleport = next_round
	_teleport_countdown = 3.0
	teleport_warning.emit(_teleport_target, _teleport_countdown)


# Forces the clean Boss-checkpoint failure path for timeout, death, or three final misses.
func fail_boss(reason: String) -> void:
	if not active:
		return
	active = false
	state = BossState.INACTIVE
	_avatar.active = false
	_avatar.set_core_exposed(false)
	failed.emit(reason)


# Reports that exactly one authored Boss body exists and is active.
func active_boss_body_count() -> int:
	return 1 if _avatar != null and _avatar.active and _avatar.visible else 0


# Returns the universe currently containing the single Boss body.
func _current_world() -> PhaseWorldSide:
	return _lu_world if current_side == EntangledEntity.Side.LU_HENG else _xing_world


# Returns the player currently being pursued by the single Boss body.
func _current_player() -> PhasePlayer:
	return _current_world().get_player()


# Completes physical reparenting and optionally enters the next mechanism round.
func _complete_teleport() -> void:
	current_side = _teleport_target
	var target_viewport: SubViewport = _lu_viewport if current_side == EntangledEntity.Side.LU_HENG else _xing_viewport
	_avatar.reparent(target_viewport, false)
	_avatar.position = _current_world().get_boss_spawn_position()
	teleport_completed.emit(current_side)
	if _next_round_after_teleport == 2:
		_start_round_two()
	_next_round_after_teleport = 0


# Runs pursuit plus ordinary and solo-readable guard-breaking attack cadence.
func _update_attacks(delta: float) -> void:
	var player: PhasePlayer = _current_player()
	_avatar.chase(player.position, delta)
	_normal_attack_timer -= delta
	_break_attack_timer -= delta
	if _break_countdown > 0.0:
		_break_countdown = maxf(_break_countdown - delta, 0.0)
		if is_zero_approx(_break_countdown):
			_avatar.show_attack_charge(false)
			player.take_damage(1, true)
			_break_attack_timer = 7.0
		return
	if _break_attack_timer <= 0.0:
		_break_countdown = BREAK_WARNING_SECONDS
		_avatar.show_attack_charge(true)
		break_attack_warning.emit(current_side, _break_countdown)
		return
	if _normal_attack_timer <= 0.0:
		_normal_attack_timer = 3.2
		if _avatar.position.distance_to(player.position) <= 135.0:
			player.take_damage(1, false)


# Enters the single delayed magnetic-clamp round after the Boss reaches Xing Yao.
func _start_round_two() -> void:
	state = BossState.ROUND_TWO
	_round_timeout = 75.0
	_support.start_round(2)
	for pipeline: PhaseCausalPipeline in _trap_pipelines.values():
		pipeline.reset_pipeline(false)
	for device: PoweredDevice in _trap_devices.values():
		device.set_powered(false)
	round_started.emit(2)
	_open_trap_window(TRAP_ORDER[0])


# Enters the final core-power and heavy-strike closure without creating a second Boss body.
func _start_round_three() -> void:
	state = BossState.ROUND_THREE
	_round_timeout = 75.0
	_phase_three_teleport_timer = 7.0
	_support.start_round(3)
	_set_active_trap_pipeline(&"")
	_final_pipeline.reset_pipeline(false)
	_final_pipeline.set_interaction_enabled(true)
	_avatar.set_core_exposed(false)
	round_started.emit(3)


# Opens one forgiving named trap window centered after its authored line delay.
func _open_trap_window(trap_id: StringName) -> void:
	var center_time := EntanglementBus.current_time + 4.5
	_support.open_trap_window(trap_id, center_time)
	_set_active_trap_pipeline(trap_id)
	trap_window_opened.emit(trap_id, center_time, _support.trap_window_tolerance)


# Applies one delayed authored parasite result as a Boss armor break and stun.
func _on_round_one_progress(_armor_id: StringName, _count: int, _total: int) -> void:
	_avatar.apply_stun(0.8)


# Resolves the authored clamp and disables its physical pipeline.
func _on_round_two_progress(trap_id: StringName, count: int, total: int) -> void:
	_avatar.apply_stun(0.55)
	(_trap_pipelines[trap_id] as PhaseCausalPipeline).set_interaction_enabled(false)
	trap_resolved.emit(trap_id, true)
	if count < total:
		_open_trap_window(TRAP_ORDER[count])


# Resets only the mistimed pipeline and clamp before reopening the same named window.
func _on_trap_missed(trap_id: StringName) -> void:
	var pipeline := _trap_pipelines[trap_id] as PhaseCausalPipeline
	pipeline.reset_pipeline(false)
	pipeline.set_interaction_enabled(true)
	(_trap_devices[trap_id] as PoweredDevice).set_powered(false)
	trap_resolved.emit(trap_id, false)
	_open_trap_window(trap_id)


# Exposes, decays, or closes the final Boss core from structured support state.
func _on_final_progress(has_power: bool, has_core: bool, seconds_left: float) -> void:
	if has_power and not has_core:
		_avatar.set_core_exposed(true)
		_avatar.apply_stun(seconds_left)
	elif not has_power:
		_avatar.set_core_exposed(false)
	final_window_changed.emit(has_power, has_core, seconds_left)


# Re-arms the final core pipeline after one miss and fails only after the third complete window.
func _on_final_attempt_missed(count: int, total: int) -> void:
	_avatar.set_core_exposed(false)
	_final_pipeline.reset_pipeline(false)
	_final_pipeline.set_interaction_enabled(count < total)
	if count >= total:
		fail_boss("核心窗口连续错过三次")


# Routes only explicit Boss virtual links; real traps arrive through their authored devices.
func _on_entanglement_event_arrived(event: EntanglementEvent) -> void:
	if state == BossState.ROUND_ONE and event.event_type == EntanglementBus.DESTROYED and ARMOR_LINKS.has(event.link_id):
		if bool(event.payload.get("value", true)):
			_support.register_armor_arrival(ARMOR_LINKS[event.link_id])
	elif state == BossState.ROUND_THREE and event.link_id == FINAL_POWER_LINK and event.event_type == EntanglementBus.POWER_CHANGED:
		if bool(event.payload.get("value", false)):
			_support.open_final_window(event.arrival_time)


# Converts one real powered device arrival into the matching structured trap id.
func _on_trap_device_arrived(event: EntanglementEvent, trap_id: StringName) -> void:
	if state != BossState.ROUND_TWO or event.link_id != _trap_link_for_id(trap_id):
		return
	if event.event_type == EntanglementBus.POWER_CHANGED and bool(event.payload.get("value", false)):
		if not _is_boss_aligned_with_trap(trap_id):
			_on_trap_missed(trap_id)
			return
		_support.register_trap_arrival(trap_id, event)


# Routes Xing Yao's heavy-family hit on the single Boss body into the active final window.
func _on_core_struck(attack_kind: StringName, break_power: int) -> void:
	if state != BossState.ROUND_THREE:
		return
	_support.register_final_strike(attack_kind, break_power, EntanglementBus.current_time)


# Transitions only when the active structured support rule reports completion.
func _on_condition_complete(round_index: int) -> void:
	if round_index == 1 and state == BossState.ROUND_ONE:
		begin_teleport(EntangledEntity.Side.XING_YAO, 2)
	elif round_index == 2 and state == BossState.ROUND_TWO:
		_start_round_three()
	elif round_index == 3 and state == BossState.ROUND_THREE:
		active = false
		state = BossState.DEFEATED
		_avatar.defeat()
		defeated.emit()


# Resets and disables every authored pipeline before a fresh Boss attempt.
func _reset_authored_mechanisms() -> void:
	for pipeline: PhaseCausalPipeline in _trap_pipelines.values():
		pipeline.reset_pipeline(false)
		pipeline.set_interaction_enabled(false)
	for device: PoweredDevice in _trap_devices.values():
		device.set_powered(false)
	if _final_pipeline != null:
		_final_pipeline.reset_pipeline(false)
		_final_pipeline.set_interaction_enabled(false)


# Enables only the named round-two pipeline and keeps the core route inert.
func _set_active_trap_pipeline(active_trap_id: StringName) -> void:
	for trap_id: StringName in TRAP_ORDER:
		(_trap_pipelines[trap_id] as PhaseCausalPipeline).set_interaction_enabled(trap_id == active_trap_id)
	if _final_pipeline != null:
		_final_pipeline.set_interaction_enabled(false)


# Requires Xing Yao to hold the Boss beneath the authored clamp at arrival time.
func _is_boss_aligned_with_trap(trap_id: StringName) -> bool:
	if trap_id != &"clamp" or current_side != EntangledEntity.Side.XING_YAO:
		return false
	var clamp := _trap_devices[trap_id] as Node2D
	return absf(_avatar.global_position.x - clamp.global_position.x) <= 260.0


# Finds the explicit bus link assigned to one structured authored trap id.
func _trap_link_for_id(trap_id: StringName) -> StringName:
	for link_id: StringName in TRAP_LINKS:
		if TRAP_LINKS[link_id] == trap_id:
			return link_id
	return &""


# Disconnects prior authored device callbacks before rebinding a reloaded Boss room.
func _disconnect_trap_device_callbacks() -> void:
	for trap_id: StringName in _trap_device_callbacks:
		var device_value: Variant = _trap_devices.get(trap_id)
		var callback: Callable = _trap_device_callbacks[trap_id]
		if not is_instance_valid(device_value):
			continue
		var device := device_value as PoweredDevice
		if device.remote_event_applied.is_connected(callback):
			device.remote_event_applied.disconnect(callback)
	_trap_device_callbacks.clear()
