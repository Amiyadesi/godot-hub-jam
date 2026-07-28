class_name PoweredDevice
extends EntangledEntity
## Shared remote-power contract for authored doors, platforms, lasers, and shields.

signal power_state_changed(powered: bool)

@export var active_high: bool = true
@export var starts_powered: bool = false
@export var accepted_event_type: StringName = EntanglementBus.POWER_CHANGED
@export_enum("无", "锁存关闭", "锁存开启") var latch_effective_state: int = -1

var powered: bool = false
var interference_active: bool = false
var interference_mode: StringName = &""
var _latched_effective_state: int = -1


# Registers the receiver and presents the authored initial state without treating it as an arrived edge.
func _ready() -> void:
	super._ready()
	powered = starts_powered
	_apply_power_state(_effective_power(powered))


# Applies only boolean power events and never emits a feedback event.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if event.event_type != accepted_event_type:
		return
	var default_value := event.event_type != EntanglementBus.POWER_CHANGED
	set_powered(bool(event.payload.get("value", default_value)))


# Changes the stable device state and delegates concrete physical behavior.
func set_powered(value: bool) -> void:
	if _latched_effective_state >= 0:
		_apply_power_state(_latched_effective_state == 1)
		return
	if powered == value:
		var unchanged_effective := _effective_power(powered)
		_apply_power_state(unchanged_effective)
		_try_latch_effective_state(unchanged_effective)
		return
	powered = value
	var effective := _effective_power(powered)
	_apply_power_state(effective)
	_try_latch_effective_state(effective)
	power_state_changed.emit(powered)


# Applies a parasite override while retaining the underlying already-arrived power state.
func set_phase_interference(active: bool, mode: StringName = &"jam_off") -> void:
	interference_active = active
	interference_mode = mode if active else &""
	_apply_power_state(_latched_effective_state == 1 if _latched_effective_state >= 0 else _effective_power(powered))


# Clears a device's effective-state latch for an authored room reset.
func reset_latch() -> void:
	_latched_effective_state = -1
	_apply_power_state(_effective_power(powered))


# Captures the stable state allowed to survive a clean checkpoint.
func capture_persistent_state() -> Dictionary:
	return {
		"powered": powered,
		"latched_effective_state": _latched_effective_state,
	}


# Restores one already-arrived stable checkpoint state without queuing causality.
func restore_persistent_state(state: Dictionary) -> void:
	interference_active = false
	interference_mode = &""
	_latched_effective_state = int(state.get("latched_effective_state", -1))
	powered = bool(state.get("powered", starts_powered))
	_apply_power_state(_latched_effective_state == 1 if _latched_effective_state >= 0 else _effective_power(powered))


# Records the first matching effective edge as a persistent historical fact.
func _try_latch_effective_state(effective: bool) -> void:
	if latch_effective_state < 0 or _latched_effective_state >= 0:
		return
	if effective == (latch_effective_state == 1):
		_latched_effective_state = latch_effective_state


# Resolves polarity and temporary parasite forcing exactly once for every concrete device.
func _effective_power(value: bool) -> bool:
	var effective := value if active_high else not value
	if not interference_active:
		return effective
	match interference_mode:
		&"force_on":
			return true
		&"invert":
			return not effective
		&"cut", &"jam_off":
			return false
		_:
			return effective


# Requires each concrete powered device to implement its authored physical response.
func _apply_power_state(_value: bool) -> void:
	push_error("%s must implement _apply_power_state" % name)
