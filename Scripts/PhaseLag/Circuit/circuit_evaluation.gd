class_name CircuitEvaluation
extends RefCounted
## Immutable-style result returned by a physical circuit evaluation.

var valid: bool = true
var short_circuit: bool = false
var diagnostics: PackedStringArray = []
var outputs: Dictionary[StringName, Dictionary] = {}


# Stores one authored output's reachability, boolean state, and accumulated delay.
func set_output(output_id: StringName, powered: bool, delay: float, reachable: bool = true) -> void:
	outputs[output_id] = {
		"powered": powered,
		"delay": maxf(delay, 0.0),
		"reachable": reachable,
	}


# Returns an isolated output record or a stable unreachable default.
func get_output(output_id: StringName) -> Dictionary:
	return (outputs.get(output_id, {
		"powered": false,
		"delay": 0.0,
		"reachable": false,
	}) as Dictionary).duplicate(true)


# Marks the evaluated topology invalid and records a designer-facing reason.
func mark_short(reason: String) -> void:
	valid = false
	short_circuit = true
	if not diagnostics.has(reason):
		diagnostics.append(reason)
