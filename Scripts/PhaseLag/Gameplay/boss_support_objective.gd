class_name BossSupportObjective
extends Node
## Structured validator for authored armor, trap, and final heavy-strike Boss objectives.

signal round_one_progress(armor_id: StringName, count: int, total: int)
signal round_two_progress(trap_id: StringName, count: int, total: int)
signal trap_missed(trap_id: StringName)
signal final_progress(has_power: bool, has_core: bool, seconds_left: float)
signal final_attempt_missed(count: int, total: int)
signal condition_complete(round_index: int)

const TOTAL_ARMOR_OBJECTIVES: int = 3
const TOTAL_TRAP_OBJECTIVES: int = 1
const FINAL_WINDOW: float = 4.0
const MAX_FINAL_MISSES: int = 3
const ARMOR_IDS: Array[StringName] = [&"armor_a", &"armor_b", &"armor_c"]
const TRAP_IDS: Array[StringName] = [&"clamp"]

var round_index: int = 0
var expected_trap_id: StringName = &""
var trap_window_center: float = 0.0
var trap_window_tolerance: float = 1.75

var _interference_hits: Dictionary[StringName, bool] = {}
var _trap_hits: Dictionary[StringName, bool] = {}
var _final_power_time: float = -1.0
var _final_core_time: float = -1.0
var _final_deadline: float = -1.0
var _final_misses: int = 0


# Clears all structured support state before entering one Boss mechanism round.
func start_round(value: int) -> void:
	round_index = value
	expected_trap_id = &""
	trap_window_center = 0.0
	_interference_hits.clear()
	_trap_hits.clear()
	_final_power_time = -1.0
	_final_core_time = -1.0
	_final_deadline = -1.0
	if value != 3:
		_final_misses = 0


# Opens the next named phase-trap arrival window around an absolute bus time.
func open_trap_window(trap_id: StringName, center_time: float) -> void:
	if not TRAP_IDS.has(trap_id):
		push_error("BossSupportObjective.open_trap_window: unknown trap '%s'" % trap_id)
		return
	expected_trap_id = trap_id
	trap_window_center = center_time


# Counts one unique authored parasite result after its delayed destruction reaches the Boss.
func register_armor_arrival(armor_id: StringName) -> bool:
	if round_index != 1 or not ARMOR_IDS.has(armor_id) or _interference_hits.has(armor_id):
		return false
	_interference_hits[armor_id] = true
	round_one_progress.emit(armor_id, _interference_hits.size(), TOTAL_ARMOR_OBJECTIVES)
	if _interference_hits.size() == TOTAL_ARMOR_OBJECTIVES:
		condition_complete.emit(1)
	return true


# Validates one real authored trap-device arrival against the active named timing window.
func register_trap_arrival(trap_id: StringName, event: EntanglementEvent) -> bool:
	if round_index != 2 or trap_id != expected_trap_id or _trap_hits.has(trap_id):
		return false
	if absf(event.arrival_time - trap_window_center) > trap_window_tolerance:
		trap_missed.emit(trap_id)
		return false
	_trap_hits[trap_id] = true
	round_two_progress.emit(trap_id, _trap_hits.size(), TOTAL_TRAP_OBJECTIVES)
	if _trap_hits.size() == TOTAL_TRAP_OBJECTIVES:
		condition_complete.emit(2)
	return true


# Opens the four-second Xing Yao heavy-strike window from one arrived final power event.
func open_final_window(arrival_time: float) -> bool:
	if round_index != 3 or is_final_window_open():
		return false
	_final_power_time = arrival_time
	_final_core_time = -1.0
	_final_deadline = arrival_time + FINAL_WINDOW
	final_progress.emit(true, false, FINAL_WINDOW)
	return true


# Accepts only a heavy-family strike before the arrived final power window expires.
func register_final_strike(attack_kind: StringName, break_power: int, strike_time: float) -> bool:
	if not is_final_window_open() or strike_time > _final_deadline:
		return false
	if attack_kind not in [&"heavy", &"counter"] or break_power < 3:
		return false
	_final_core_time = strike_time
	final_progress.emit(true, true, get_final_window_remaining(strike_time))
	condition_complete.emit(3)
	return true


# Expires an unanswered final window and counts the miss without resetting earlier Boss rounds.
func tick(current_time: float) -> void:
	if not is_final_window_open() or _final_core_time >= 0.0 or current_time <= _final_deadline:
		return
	_final_misses += 1
	_final_power_time = -1.0
	_final_core_time = -1.0
	_final_deadline = -1.0
	final_progress.emit(false, false, 0.0)
	final_attempt_missed.emit(_final_misses, MAX_FINAL_MISSES)


# Reports whether the final core is currently vulnerable to Xing Yao's heavy strike.
func is_final_window_open() -> bool:
	return _final_power_time >= 0.0 and _final_core_time < 0.0 and _final_deadline >= 0.0


# Returns the remaining visual decay duration for the active final core half.
func get_final_window_remaining(current_time: float = -1.0) -> float:
	if not is_final_window_open():
		return 0.0
	var now := EntanglementBus.current_time if current_time < 0.0 else current_time
	return maxf(_final_deadline - now, 0.0)


# Exposes the current complete-window miss count for deterministic tests and controller rules.
func final_miss_count() -> int:
	return _final_misses
