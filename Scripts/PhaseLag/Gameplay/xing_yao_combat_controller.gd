class_name XingYaoCombatController
extends Node
## Deterministic rescue-blade combat state machine with explicit active frames and counter reward.

signal attack_started(kind: StringName, combo_step: int)
signal attack_active(kind: StringName, damage: int, break_power: int)
signal attack_finished(kind: StringName)
signal counter_succeeded

enum State {
	IDLE,
	QUICK_STARTUP,
	QUICK_ACTIVE,
	QUICK_RECOVERY,
	HEAVY_CHARGE,
	HEAVY_ACTIVE,
	HEAVY_RECOVERY,
	COUNTER_ACTIVE,
	AIR_SLASH_ACTIVE,
	DIVE_ACTIVE,
}

const QUICK_STARTUP: float = 0.16
const QUICK_ACTIVE: float = 0.12
const QUICK_RECOVERY: float = 0.08
const HEAVY_ACTIVE: float = 0.16
const HEAVY_RECOVERY: float = 0.24
const COUNTER_WINDOW: float = 0.18
const COUNTER_ACTIVE: float = 0.14
const AIR_ACTION_TIME: float = 0.28
const ATTACK_OFFSET_X: float = 145.0

var state: State = State.IDLE
var combo_step: int = 0
var current_damage: int = 0
var current_break_power: int = 0
var _attack_kind: StringName = &""
var _state_time: float = 0.0
var _charge_time: float = 0.0
var _queued_quick: bool = false
var _player: PhasePlayer
var _attack_area: Area2D
var _hit_targets: Array[Node] = []


# Resolves the authored player and sword hit area without creating runtime collision nodes.
func _ready() -> void:
	_player = get_parent() as PhasePlayer
	if _player == null:
		push_error("XingYaoCombatController must be an authored child of PhasePlayer")
		return
	_attack_area = _player.get_node("AttackArea") as Area2D
	_attack_area.body_entered.connect(_on_attack_body_entered)
	_attack_area.area_entered.connect(_on_attack_area_entered)
	_attack_area.monitoring = false


# Starts or buffers J as a ground combo slash or a distinct airborne pursuit slash.
func request_primary(on_floor: bool) -> bool:
	if not on_floor:
		if state != State.IDLE:
			return false
		_start_air_action(&"air_slash", State.AIR_SLASH_ACTIVE, 2, 1)
		return true
	if state == State.IDLE:
		combo_step = 1
		_start_quick(combo_step)
		return true
	if state in [State.QUICK_STARTUP, State.QUICK_ACTIVE, State.QUICK_RECOVERY] and combo_step < 3:
		_queued_quick = true
		return true
	return false


# Starts K as heavy charge with a brief precision-counter stance or as an airborne dive.
func request_secondary_pressed(on_floor: bool) -> bool:
	if state != State.IDLE:
		return false
	if not on_floor:
		_start_air_action(&"dive", State.DIVE_ACTIVE, 3, 3)
		return true
	state = State.HEAVY_CHARGE
	_attack_kind = &"heavy"
	_charge_time = 0.0
	current_damage = 2
	current_break_power = 3
	_hit_targets.clear()
	if _player != null:
		_player.play_role_animation(&"charge", 999.0)
	attack_started.emit(_attack_kind, 0)
	return true


# Releases a held K into a charged armor-breaking active window.
func request_secondary_released() -> bool:
	if state != State.HEAVY_CHARGE:
		return false
	current_damage = 2 if _charge_time < 0.45 else 3
	current_break_power = 3
	state = State.HEAVY_ACTIVE
	_state_time = HEAVY_ACTIVE
	if _player != null:
		_player.play_role_animation(&"heavy", HEAVY_ACTIVE + HEAVY_RECOVERY)
	_activate_attack(&"heavy")
	return true


# Converts an incoming enemy strike during startup into the optional high-damage counter.
func notify_incoming_attack() -> bool:
	if state != State.HEAVY_CHARGE or _charge_time > COUNTER_WINDOW:
		return false
	state = State.COUNTER_ACTIVE
	_attack_kind = &"counter"
	_state_time = COUNTER_ACTIVE
	current_damage = 4
	current_break_power = 4
	if _player != null:
		_player.play_role_animation(&"counter", COUNTER_ACTIVE + HEAVY_RECOVERY)
	_activate_attack(&"counter")
	counter_succeeded.emit()
	return true


# Lets L cancel quick recovery while PhasePlayer owns the actual ground or air dash.
func request_dodge() -> bool:
	if state in [State.QUICK_STARTUP, State.QUICK_ACTIVE, State.QUICK_RECOVERY]:
		_finish_attack()
		return true
	return state == State.IDLE


# Advances active frames and recovery deterministically for runtime and headless tests.
func advance(delta: float) -> void:
	if delta <= 0.0 or state == State.IDLE:
		return
	if state == State.HEAVY_CHARGE:
		_charge_time += delta
		return
	var remaining := delta
	while remaining > 0.0 and state != State.IDLE and state != State.HEAVY_CHARGE:
		if remaining < _state_time:
			_state_time -= remaining
			remaining = 0.0
		else:
			remaining -= _state_time
			_state_time = 0.0
			_advance_state()


# Reports whether the sword's authored hit area is currently damaging targets.
func is_attack_active() -> bool:
	return state in [State.QUICK_ACTIVE, State.HEAVY_ACTIVE, State.COUNTER_ACTIVE, State.AIR_SLASH_ACTIVE, State.DIVE_ACTIVE]


# Returns the current one-based quick-chain position.
func get_combo_step() -> int:
	return combo_step


# Returns the current animation and damage grammar identifier.
func get_attack_kind() -> StringName:
	return _attack_kind


# Reports whether normal horizontal movement should remain available.
func can_move() -> bool:
	return state in [State.IDLE, State.QUICK_RECOVERY]


# Cancels charge, combo, active hitboxes, and buffered input during ownership or room resets.
func reset_action_state() -> void:
	_deactivate_hitbox()
	state = State.IDLE
	_state_time = 0.0
	_charge_time = 0.0
	_queued_quick = false
	combo_step = 0
	current_damage = 0
	current_break_power = 0
	_attack_kind = &""
	_hit_targets.clear()


# Starts one of the three grounded quick-slash startup windows.
func _start_quick(step: int) -> void:
	state = State.QUICK_STARTUP
	_state_time = QUICK_STARTUP
	_attack_kind = StringName("slash_%d" % step)
	current_damage = 1
	current_break_power = 1
	_queued_quick = false
	_hit_targets.clear()
	if _player != null:
		_player.play_role_animation(_attack_kind, QUICK_STARTUP + QUICK_ACTIVE + QUICK_RECOVERY)
	attack_started.emit(_attack_kind, combo_step)


# Starts one authored airborne attack with its own damage and break values.
func _start_air_action(kind: StringName, next_state: State, damage: int, break_power: int) -> void:
	state = next_state
	_state_time = AIR_ACTION_TIME
	_attack_kind = kind
	current_damage = damage
	current_break_power = break_power
	combo_step = 0
	_hit_targets.clear()
	if _player != null:
		_player.play_role_animation(kind, AIR_ACTION_TIME)
	attack_started.emit(kind, 0)
	_activate_hitbox()
	attack_active.emit(kind, current_damage, current_break_power)


# Moves the state machine from startup to active frames, recovery, or the next combo slash.
func _advance_state() -> void:
	match state:
		State.QUICK_STARTUP:
			state = State.QUICK_ACTIVE
			_state_time = QUICK_ACTIVE
			_activate_attack(_attack_kind)
		State.QUICK_ACTIVE:
			_deactivate_hitbox()
			state = State.QUICK_RECOVERY
			_state_time = QUICK_RECOVERY
		State.QUICK_RECOVERY:
			if _queued_quick and combo_step < 3:
				combo_step += 1
				_start_quick(combo_step)
			else:
				_finish_attack()
		State.HEAVY_ACTIVE, State.COUNTER_ACTIVE:
			_deactivate_hitbox()
			state = State.HEAVY_RECOVERY
			_state_time = HEAVY_RECOVERY
		State.HEAVY_RECOVERY, State.AIR_SLASH_ACTIVE, State.DIVE_ACTIVE:
			_finish_attack()
		_:
			_finish_attack()


# Opens the sword hit area and announces one explicit damage window.
func _activate_attack(kind: StringName) -> void:
	_attack_kind = kind
	_activate_hitbox()
	attack_active.emit(kind, current_damage, current_break_power)


# Enables the authored attack area and immediately samples existing overlaps.
func _activate_hitbox() -> void:
	if _attack_area == null:
		return
	_attack_area.position.x = ATTACK_OFFSET_X * (_player.facing if _player != null else 1.0)
	_attack_area.scale = Vector2.ONE
	_attack_area.set_deferred("monitoring", true)
	call_deferred("_sample_overlapping_targets")


# Disables the authored attack area after its explicit active frames end.
func _deactivate_hitbox() -> void:
	if _attack_area != null:
		_attack_area.set_deferred("monitoring", false)


# Returns to idle and clears combo, charge, and hitbox state.
func _finish_attack() -> void:
	var finished_kind := _attack_kind
	reset_action_state()
	attack_finished.emit(finished_kind)


# Applies the active attack payload once to every overlapping body or hit area.
func _sample_overlapping_targets() -> void:
	if _attack_area == null or not is_attack_active():
		return
	for body: Node2D in _attack_area.get_overlapping_bodies():
		_try_hit_target(body)
	for area: Area2D in _attack_area.get_overlapping_areas():
		_try_hit_target(area)


# Routes a body-entered callback through the same one-hit-per-swing rule.
func _on_attack_body_entered(body: Node2D) -> void:
	_try_hit_target(body)


# Routes an area-entered callback through the same one-hit-per-swing rule.
func _on_attack_area_entered(area: Area2D) -> void:
	_try_hit_target(area)


# Calls the authored receive_attack contract once during a legal active window.
func _try_hit_target(target: Node) -> void:
	if not is_attack_active() or target == null or _hit_targets.has(target):
		return
	var receiver: Node = target
	if not receiver.has_method("receive_attack") and receiver.get_parent() != null:
		receiver = receiver.get_parent()
	if not receiver.has_method("receive_attack"):
		return
	_hit_targets.append(target)
	receiver.call("receive_attack", {
		"damage": current_damage,
		"break_power": current_break_power,
		"kind": _attack_kind,
		"direction": _player.facing if _player != null else 1.0,
	})
