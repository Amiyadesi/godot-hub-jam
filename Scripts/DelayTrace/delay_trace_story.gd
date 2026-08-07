class_name DelayTraceStory
extends Node
## Orchestrates memory pickups, the false deadline, and normal-ending persistence.

const MEMORY_SEQUENCES := {
	"memory_t_minus_5": {
		"tag": "STORY_MEMORY_MINUS_5",
		"lines": [
			"STORY_MEMORY_MINUS_5_LINE_1",
			"STORY_MEMORY_MINUS_5_LINE_2",
			"STORY_MEMORY_MINUS_5_LINE_3",
			"STORY_MEMORY_MINUS_5_LINE_4",
		],
	},
	"memory_t_minus_3": {
		"tag": "STORY_MEMORY_MINUS_3",
		"lines": [
			"STORY_MEMORY_MINUS_3_LINE_1",
			"STORY_MEMORY_MINUS_3_LINE_2",
			"STORY_MEMORY_MINUS_3_LINE_3",
		],
	},
	"memory_t_minus_1": {
		"tag": "STORY_MEMORY_MINUS_1",
		"lines": [
			"STORY_MEMORY_MINUS_1_LINE_1",
			"STORY_MEMORY_MINUS_1_LINE_2",
		],
	},
	"memory_after": {
		"tag": "STORY_MEMORY_AFTER",
		"lines": [
			"STORY_MEMORY_AFTER_LINE_1",
			"STORY_MEMORY_AFTER_LINE_2",
			"STORY_MEMORY_AFTER_LINE_3",
			"STORY_MEMORY_AFTER_LINE_4",
			"STORY_MEMORY_AFTER_LINE_5",
			"STORY_MEMORY_AFTER_LINE_6",
		],
	},
}
const BRANCH_DEVICE_IDS := ["delay1s", "delay3s", "delay5s"]
const FLAG_NORMAL_ENDING_SEEN := "normal_ending_seen"

@export var gameplay_world: Node2D
@export var player: EchoPlayer
@export var narrative_presenter: DelayTraceNarrativePresenter
@export var normal_ending_trigger: Area2D
@export var final_return_point: Marker2D

var _story_queue: Array[Dictionary] = []
var _story_playing := false
var _ending_active := false
var _normal_ending_pending := false


# Connects authored story components and restores no transient cinematic state.
func _ready() -> void:
	if (
		LevelModule.instance == null
		or NarrativeSlotModule.instance == null
		or gameplay_world == null
		or player == null
		or narrative_presenter == null
		or normal_ending_trigger == null
		or final_return_point == null
	):
		push_error("DelayTraceStory requires save modules and all authored story nodes")
		return
	for node in gameplay_world.find_children("*", "TemporalCollectible", true, false):
		(node as TemporalCollectible).collected.connect(_on_memory_collected)
	EchoTimeline.run_countdown_expired.connect(_on_run_countdown_expired)
	normal_ending_trigger.body_entered.connect(_on_normal_ending_body_entered)


# Queues one red-text shard memory without interrupting the player with Keeper dialogue.
func _on_memory_collected(item_id: StringName) -> void:
	var memory_id := String(item_id)
	if not MEMORY_SEQUENCES.has(memory_id):
		return
	var sequence: Dictionary = MEMORY_SEQUENCES[memory_id]
	_enqueue_memory(sequence["lines"] as Array, String(sequence["tag"]))


# Persists the false deadline so the player can ask the Keeper about it later.
func _on_run_countdown_expired() -> void:
	if not LevelModule.instance.mark_run_countdown_expired():
		return
	if not SaveSystem.save_slot(1):
		push_error("DelayTraceStory failed to save the expired run countdown")


# Starts the staged loop ending when all three branch devices are complete.
func _on_normal_ending_body_entered(body: Node2D) -> void:
	if _ending_active or body != player or not _branches_complete():
		return
	if _story_playing:
		_normal_ending_pending = true
		return
	_ending_active = true
	EchoTimeline.set_gameplay_active(false)
	_set_narrative_flag(FLAG_NORMAL_ENDING_SEEN)
	await narrative_presenter.play_normal_ending()
	player.reset_player(final_return_point.global_position)
	EchoTimeline.reset_timeline(
		EchoTimeline.get_selected_past_delay_seconds(),
		EchoTimeline.get_selected_delay_switch_id()
	)
	EchoTimeline.set_gameplay_active(true)
	_ending_active = false


# Appends one authored red-text memory and starts the serialized playback loop.
func _enqueue_memory(line_keys: Array, time_tag_key: String) -> void:
	_story_queue.append({
		"lines": line_keys,
		"time_tag": time_tag_key,
	})
	if not _story_playing:
		_drain_story_queue()

# Plays queued red-text memories without overlapping pause ownership.
func _drain_story_queue() -> void:
	_story_playing = true
	while not _story_queue.is_empty():
		var sequence: Dictionary = _story_queue.pop_front()
		await narrative_presenter.play_memory_sequence(
			sequence["lines"] as Array,
			String(sequence["time_tag"])
		)
	_story_playing = false
	if _normal_ending_pending:
		_normal_ending_pending = false
		_on_normal_ending_body_entered(player)

# Requires the three free-order route devices while leaving both exits selectable.
func _branches_complete() -> bool:
	for device_id in BRANCH_DEVICE_IDS:
		if not LevelModule.instance.is_progression_device_active(device_id):
			return false
	return true


# Writes one slot-scoped story flag and immediately persists it.
func _set_narrative_flag(flag_key: String) -> void:
	NarrativeSlotModule.instance.set_flag(flag_key)
	if not SaveSystem.save_slot(1):
		push_error("DelayTraceStory failed to save narrative flag '%s'" % flag_key)
