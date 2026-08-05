class_name DialogueNpc
extends Area2D
## Authored NPC interaction using the project ModularBalloon.

signal dialogue_started_here
signal dialogue_finished

@export var dialogue_resource_zh: DialogueResource
@export var dialogue_resource_en: DialogueResource
@export var dialogue_title := "start"

@onready var interact_prompt: Label = %InteractPrompt
@onready var new_topic_indicator: Label = %NewTopicIndicator
@onready var balloon: ModularBalloon = %DialogueBalloon
@onready var visual: Sprite2D = $Visual

var _player_inside := false
var _dialogue_active := false
var _was_tree_paused := false
var _active_dialogue_resource: DialogueResource
var _face_target: Node2D


# Connects the authored trigger and dialogue lifecycle.
func _ready() -> void:
	if dialogue_resource_zh == null or dialogue_resource_en == null:
		push_error("DialogueNpc requires zh and en dialogue resources")
		return
	if LevelModule.instance == null or NarrativeSlotModule.instance == null:
		push_error("DialogueNpc requires LevelModule and NarrativeSlotModule")
		return
	_active_dialogue_resource = (
		dialogue_resource_zh
		if TranslationServer.get_locale().begins_with("zh")
		else dialogue_resource_en
	)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	balloon.dialogue_ended.connect(_on_dialogue_ended)
	LevelModule.instance.collectible_collected.connect(_on_collectible_collected)
	EchoTimeline.run_countdown_expired.connect(_on_run_countdown_expired)
	interact_prompt.hide()
	set_process(false)
	_refresh_new_topic_indicator()


# Faces the current-room player while a target is assigned.
func _process(_delta: float) -> void:
	if not is_instance_valid(_face_target):
		return
	if not is_equal_approx(_face_target.global_position.x, global_position.x):
		visual.flip_h = _face_target.global_position.x < global_position.x


# Starts dialogue only for a nearby player pressing the interaction action.
func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not _player_inside or _dialogue_active or not event.is_action_pressed(&"echo_interact"):
		return
	get_viewport().set_input_as_handled()
	start_dialogue()


# Pauses the existing world state and opens the authored balloon.
func start_dialogue() -> bool:
	if _dialogue_active:
		return false
	if _active_dialogue_resource == null:
		push_error("DialogueNpc cannot start without an active localized dialogue resource")
		return false
	_dialogue_active = true
	interact_prompt.hide()
	new_topic_indicator.hide()
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	dialogue_started_here.emit()
	balloon.start(_active_dialogue_resource, dialogue_title, [self])
	return true


# Persists one player-initiated Keeper topic after its dialogue completes.
func mark_dialogue_seen(flag_key: String) -> void:
	NarrativeSlotModule.instance.set_flag(flag_key)
	if not SaveSystem.save_slot(1):
		push_error("DialogueNpc failed to save dialogue flag '%s'" % flag_key)
	_refresh_new_topic_indicator()


# Tracks the player only while PresentRoom owns the target.
func set_face_target(target: Node2D) -> void:
	_face_target = target
	set_process(_face_target != null)
	if _face_target == null:
		visual.flip_h = false
	else:
		_process(0.0)


# Shows the interaction prompt for the current EchoPlayer only.
func _on_body_entered(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = true
	_refresh_new_topic_indicator()
	if not _dialogue_active:
		interact_prompt.show()


# Hides the prompt when the current EchoPlayer leaves range.
func _on_body_exited(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = false
	interact_prompt.hide()


# Restores the exact pause state that existed before this conversation.
func _on_dialogue_ended() -> void:
	_dialogue_active = false
	get_tree().paused = _was_tree_paused
	interact_prompt.visible = _player_inside
	_refresh_new_topic_indicator()
	dialogue_finished.emit()


# Refreshes the authored marker when collecting the first memory heart.
func _on_collectible_collected(_item_id: String) -> void:
	_refresh_new_topic_indicator()


# Defers the deadline marker until the story controller has persisted the state.
func _on_run_countdown_expired() -> void:
	call_deferred(&"_refresh_new_topic_indicator")


# Shows a marker only for newly unlocked one-shot Keeper questions.
func _refresh_new_topic_indicator() -> void:
	var has_heart_topic := (
		LevelModule.instance.get_collected_item_count() >= 1
		and not NarrativeSlotModule.instance.has_flag("askheart")
	)
	var has_time_topic := (
		LevelModule.instance.has_run_countdown_expired()
		and not NarrativeSlotModule.instance.has_flag("asktime")
	)
	new_topic_indicator.visible = not _dialogue_active and (has_heart_topic or has_time_topic)
