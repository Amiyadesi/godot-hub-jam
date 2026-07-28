class_name CircuitRunPlan
extends RefCounted
## Immutable-style schedule produced from one authored circuit snapshot.

const CIRCUIT_INTERVAL_SCRIPT: Script = preload("res://Scripts/PhaseLag/Circuit/circuit_interval.gd")

var valid: bool = true
var diagnostics: PackedStringArray = []
var intervals: Dictionary = {}
var transitions: Array = []
var end_time: float = 0.0


# Stores one output's half-open powered window.
func set_interval(output_id: StringName, interval: Variant) -> void:
	intervals[output_id] = interval.copy()
	end_time = maxf(end_time, interval.end_time)


# Returns an isolated interval or an empty interval for an unreachable output.
func get_interval(output_id: StringName) -> Variant:
	var interval: Variant = intervals.get(output_id)
	return interval.copy() if interval != null else CIRCUIT_INTERVAL_SCRIPT.new()


# Appends one edge in deterministic source-dispatch order.
func add_transition(transition: Variant) -> void:
	transitions.append(transition)
	transitions.sort_custom(_transition_dispatches_first)
	end_time = maxf(end_time, transition.at_time)


# Rejects this run plan with one designer-facing reason.
func reject(reason: String) -> void:
	valid = false
	if not diagnostics.has(reason):
		diagnostics.append(reason)


# Orders equal dispatch times with opening edges before closing edges.
func _transition_dispatches_first(a: Variant, b: Variant) -> bool:
	if is_equal_approx(a.send_time, b.send_time):
		if a.value != b.value:
			return a.value
		return String(a.output_id) < String(b.output_id)
	return a.send_time < b.send_time
