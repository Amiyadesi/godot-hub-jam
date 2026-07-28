class_name FacilityGuardPowerReceiver
extends EntangledEntity
## Entangled child component that routes delayed armor power into its authored guard parent.

@export var active_high: bool = true


# Applies only boolean armor power events to the owning facility guard.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if event.event_type != EntanglementBus.POWER_CHANGED:
		return
	var guard := get_parent() as FacilityGuard
	if guard == null:
		push_error("FacilityGuardPowerReceiver must be an authored child of FacilityGuard")
		return
	var powered := bool(event.payload.get("value", false))
	guard.set_armor_powered(powered if active_high else not powered)
