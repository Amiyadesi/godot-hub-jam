class_name RunCountdownHUD
extends Control
## Displays the remaining whole-run limit without owning its clock.

@onready var countdown_label: Label = %CountdownLabel


# Connects the HUD to the persistent run-limit signal and paints its initial value.
func _ready() -> void:
	EchoTimeline.run_countdown_changed.connect(_on_run_countdown_changed)
	_on_run_countdown_changed(EchoTimeline.get_run_countdown_remaining(), 0.0)


# Formats the remaining run time as a compact minute-and-second readout.
func _on_run_countdown_changed(remaining_seconds: float, _maximum_seconds: float) -> void:
	var total_seconds := maxi(0, ceili(remaining_seconds))
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	countdown_label.text = "%02d:%02d" % [minutes, seconds]
