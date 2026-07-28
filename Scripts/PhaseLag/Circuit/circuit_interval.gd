class_name CircuitInterval
extends RefCounted
## One half-open powered interval on a circuit output timeline.

var start_time: float = 0.0
var end_time: float = 0.0


# Creates a normalized [start, end) interval.
func _init(start_seconds: float = 0.0, end_seconds: float = 0.0) -> void:
	start_time = maxf(start_seconds, 0.0)
	end_time = maxf(end_seconds, start_time)


# Returns the usable powered-window length.
func duration() -> float:
	return end_time - start_time


# Creates an isolated interval copy for tests and UI readouts.
func copy() -> Variant:
	return get_script().new(start_time, end_time)
