class_name KnowledgeLock
extends Node2D
## Activates the true-ending lock only when Past catches this recorder's active recording.

@export var source_recorder: FutureRecorder
@export var device_id: StringName = &"knowledge_lock"

@onready var locked_visual: CanvasItem = %LockedVisual
@onready var unlocked_visual: CanvasItem = %UnlockedVisual
@onready var unlock_audio: AudioStreamPlayer2D = %UnlockAudio

var _unlocked := false


# Restores the authored lock and listens for the one qualifying recording outcome.
func _ready() -> void:
	if source_recorder == null:
		push_error("KnowledgeLock requires a source_recorder")
		return
	if device_id.is_empty() or LevelModule.instance == null:
		push_error("KnowledgeLock requires a device_id and LevelModule")
		return
	EchoTimeline.future_recording_committed_by_past.connect(_on_recording_committed_by_past)
	_set_unlocked(LevelModule.instance.is_progression_device_active(String(device_id)), false)


# Reports whether the true-ending recording action has already succeeded.
func is_unlocked() -> bool:
	return _unlocked


# Accepts only a Past-catch commit produced by this authored recorder.
func _on_recording_committed_by_past(recorder: FutureRecorder) -> void:
	if _unlocked or recorder != source_recorder:
		return
	if not LevelModule.instance.activate_progression_device(String(device_id)):
		return
	_set_unlocked(true, true)
	if not SaveSystem.save_slot(1):
		push_error("KnowledgeLock failed to save slot 1")


# Swaps the authored lock state and optional success feedback.
func _set_unlocked(value: bool, play_feedback: bool) -> void:
	_unlocked = value
	locked_visual.visible = not value
	unlocked_visual.visible = value
	if play_feedback:
		unlock_audio.play()
