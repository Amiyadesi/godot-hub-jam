class_name DelayPickup
extends Area2D
## One-use authored delay selector for the permanent past body.

@export_enum("1", "3", "5") var delay_seconds := 3
@export var timeline: EchoTimelineController


# Requires a direct timeline link and wires the authored player trigger.
func _ready() -> void:
	assert(timeline != null, "DelayPickup requires an authored EchoTimelineController reference")
	body_entered.connect(_on_body_entered)


# Selects a new past delay once and removes this authored one-use pickup.
func _on_body_entered(body: Node2D) -> void:
	if body != timeline.player:
		return
	timeline.set_past_delay(float(delay_seconds))
	queue_free()
