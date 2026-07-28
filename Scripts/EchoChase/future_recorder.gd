class_name FutureRecorder
extends Area2D
## Authored trigger that begins one possibility recording when the player enters it.

signal recording_started_here
signal recording_finished_here
signal recording_rejected_here

@export var timeline: EchoTimelineController

var _requires_exit_before_restart := false


# Requires a direct timeline link and wires the authored entry trigger.
func _ready() -> void:
	assert(timeline != null, "FutureRecorder requires an authored EchoTimelineController reference")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# Marks this recorder active after its controller reserves a future slot.
func recording_started() -> void:
	_requires_exit_before_restart = true
	recording_started_here.emit()


# Marks this recorder inactive after the player returns to its recorded origin.
func recording_finished() -> void:
	recording_finished_here.emit()


# Lets an authored visual react when two future slots are already occupied.
func recording_rejected() -> void:
	recording_rejected_here.emit()


# Starts recording only on an intentional fresh entry by the linked player.
func _on_body_entered(body: Node2D) -> void:
	if body != timeline.player or _requires_exit_before_restart:
		return
	if not timeline.start_future_recording(self):
		recording_rejected()


# Requires the player to leave after recall before this recorder can start again.
func _on_body_exited(body: Node2D) -> void:
	if body == timeline.player and not timeline.is_future_recording():
		_requires_exit_before_restart = false
