class_name EchoChaseStory
extends Node
## Orchestrates memory pickups, Keeper disclosures, routes, and ending persistence.

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
const COMPLETE_MEMORY_LINES := [
	"STORY_MEMORY_COMPLETE_LINE_1",
	"STORY_MEMORY_COMPLETE_LINE_2",
	"STORY_MEMORY_COMPLETE_LINE_3",
	"STORY_MEMORY_COMPLETE_LINE_4",
	"STORY_MEMORY_COMPLETE_LINE_5",
]
const BRANCH_DEVICE_IDS := ["delay1s", "delay3s", "delay5s"]
const SEQUENCE_MEMORY := &"memory"
const SEQUENCE_KEEPER := &"keeper"
const FLAG_NORMAL_ENDING_SEEN := "normal_ending_seen"
const FLAG_TRUE_ENDING_SEEN := "true_ending_seen"
const FLAG_COUNTDOWN_CONFESSION_SEEN := "countdown_confession_seen"

@export var gameplay_world: Node2D
@export var player: EchoPlayer
@export var narrative_presenter: EchoChaseNarrativePresenter
@export var true_ending_route: TrueEndingRoute
@export var normal_ending_trigger: Area2D
@export var final_return_point: Marker2D
@export_file("*.tscn") var menu_scene_path := ""

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
		or true_ending_route == null
		or normal_ending_trigger == null
		or final_return_point == null
		or menu_scene_path.is_empty()
	):
		push_error("EchoChaseStory requires save modules and all authored story nodes")
		return
	for node in gameplay_world.find_children("*", "TemporalCollectible", true, false):
		(node as TemporalCollectible).collected.connect(_on_memory_collected)
	EchoTimeline.run_countdown_expired.connect(_on_run_countdown_expired)
	normal_ending_trigger.body_entered.connect(_on_normal_ending_body_entered)
	true_ending_route.memory_reassembly_requested.connect(_on_memory_reassembly_requested)
	true_ending_route.true_ending_requested.connect(_on_true_ending_requested)


# Queues one red-text shard memory plus the two permitted Keeper reactions.
func _on_memory_collected(item_id: StringName) -> void:
	var memory_id := String(item_id)
	if not MEMORY_SEQUENCES.has(memory_id):
		return
	var sequence: Dictionary = MEMORY_SEQUENCES[memory_id]
	_enqueue_memory(sequence["lines"] as Array, String(sequence["tag"]))
	var memory_count := _memory_count()
	if memory_count == 1:
		_enqueue_keeper_dialogue("keeper_first_memory")
	elif memory_count == MEMORY_SEQUENCES.size():
		_enqueue_keeper_dialogue("keeper_all_memories")


# Persists and queues the false-deadline confession exactly once per slot.
func _on_run_countdown_expired() -> void:
	if NarrativeSlotModule.instance.has_flag(FLAG_COUNTDOWN_CONFESSION_SEEN):
		return
	_set_narrative_flag(FLAG_COUNTDOWN_CONFESSION_SEEN)
	_enqueue_keeper_dialogue("countdown_confession")


# Queues the fixed chronological reconstruction and arms the true-ending action.
func _on_memory_reassembly_requested() -> void:
	_enqueue_memory(COMPLETE_MEMORY_LINES, "STORY_MEMORY_REASSEMBLED")
	true_ending_route.arm_knowledge_lock()


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


# Persists the true ending, plays it, then returns to the authored title scene.
func _on_true_ending_requested() -> void:
	if _ending_active:
		return
	_ending_active = true
	EchoTimeline.set_gameplay_active(false)
	_set_narrative_flag(FLAG_TRUE_ENDING_SEEN)
	await narrative_presenter.play_true_ending()
	get_tree().paused = false
	SceneManager.change_scene_to_file(menu_scene_path)


# Appends one authored red-text memory and starts the serialized playback loop.
func _enqueue_memory(line_keys: Array, time_tag_key: String) -> void:
	_story_queue.append({
		"kind": SEQUENCE_MEMORY,
		"lines": line_keys,
		"time_tag": time_tag_key,
	})
	if not _story_playing:
		_drain_story_queue()


# Appends one Keeper balloon sourced from the existing Present Hub dialogue file.
func _enqueue_keeper_dialogue(title: String) -> void:
	_story_queue.append({"kind": SEQUENCE_KEEPER, "title": title})
	if not _story_playing:
		_drain_story_queue()


# Plays queued red-text memories and Keeper balloons without overlapping pause ownership.
func _drain_story_queue() -> void:
	_story_playing = true
	while not _story_queue.is_empty():
		var sequence: Dictionary = _story_queue.pop_front()
		match StringName(sequence["kind"]):
			SEQUENCE_MEMORY:
				await narrative_presenter.play_memory_sequence(
					sequence["lines"] as Array,
					String(sequence["time_tag"])
				)
			SEQUENCE_KEEPER:
				await narrative_presenter.play_keeper_dialogue(String(sequence["title"]))
	_story_playing = false
	if _normal_ending_pending:
		_normal_ending_pending = false
		_on_normal_ending_body_entered(player)


# Counts only the four stable story IDs stored by LevelModule.
func _memory_count() -> int:
	var count := 0
	for memory_id in MEMORY_SEQUENCES:
		count += int(LevelModule.instance.is_item_collected(memory_id))
	return count


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
		push_error("EchoChaseStory failed to save narrative flag '%s'" % flag_key)
