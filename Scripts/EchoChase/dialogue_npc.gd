class_name DialogueNpc
extends Area2D
## Authored NPC interaction using the project ModularBalloon.

signal dialogue_started_here
signal dialogue_finished

@export var dialogue_resource_zh: DialogueResource
@export var dialogue_resource_en: DialogueResource
@export var dialogue_title := "start"

@onready var interact_prompt: Label = %InteractPrompt
@onready var balloon: ModularBalloon = %DialogueBalloon

var _player_inside := false
var _dialogue_active := false
var _was_tree_paused := false


# Connects the authored trigger and dialogue lifecycle.
func _ready() -> void:
	if dialogue_resource_zh == null or dialogue_resource_en == null:
		push_error("DialogueNpc requires zh and en dialogue resources")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	balloon.dialogue_ended.connect(_on_dialogue_ended)
	interact_prompt.hide()


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
	var dialogue_resource := _get_localized_dialogue_resource()
	if dialogue_resource == null:
		push_error("DialogueNpc cannot start without both localized dialogue resources")
		return false
	_dialogue_active = true
	interact_prompt.hide()
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	dialogue_started_here.emit()
	balloon.start(dialogue_resource, dialogue_title, [self])
	return true


# Selects the authored resource that matches the active project locale.
func _get_localized_dialogue_resource() -> DialogueResource:
	return dialogue_resource_zh if TranslationServer.get_locale().begins_with("zh") else dialogue_resource_en


# Shows the interaction prompt for the current EchoPlayer only.
func _on_body_entered(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = true
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
	dialogue_finished.emit()
