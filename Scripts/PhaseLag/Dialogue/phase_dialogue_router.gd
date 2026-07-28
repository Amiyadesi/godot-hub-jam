class_name PhaseDialogueRouter
extends Node
## Selects authored PhaseLag balloons and rejects overlapping conversations.

signal dialogue_finished(kind: StringName, title: StringName)
signal story_finished(title: StringName)
signal bark_finished(title: StringName)

const KIND_STORY: StringName = &"story"
const KIND_BARK: StringName = &"bark"

static var instance: PhaseDialogueRouter

@export var story_resource: DialogueResource
@export var bark_resource: DialogueResource
@export var story_balloon_scene: PackedScene
@export var radio_balloon_scene: PackedScene

var _dialogue_manager: Node
var _active_resource: DialogueResource
var _active_kind: StringName = &""
var _active_title: StringName = &""
var _active_balloon: Node
var _manager_ended := false
var _balloon_closed := false


# Registers the authored router before room-local triggers become active.
func _enter_tree() -> void:
	instance = self


# Validates required Dialogue Manager resources and listens for real dialogue completion.
func _ready() -> void:
	_dialogue_manager = Engine.get_singleton("DialogueManager") as Node
	assert(_dialogue_manager != null, "PhaseDialogueRouter requires the DialogueManager autoload")
	assert(story_resource != null and bark_resource != null, "PhaseDialogueRouter requires authored dialogue resources")
	assert(story_balloon_scene != null and radio_balloon_scene != null, "PhaseDialogueRouter requires authored balloon scenes")
	_dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)


# Clears the singleton without touching conversations owned by a replacement scene.
func _exit_tree() -> void:
	if _dialogue_manager != null and _dialogue_manager.dialogue_ended.is_connected(_on_dialogue_ended):
		_dialogue_manager.dialogue_ended.disconnect(_on_dialogue_ended)
	if instance == self:
		instance = null


# Starts a blocking story conversation when no other PhaseLag dialogue is active.
func play_story(title: StringName) -> bool:
	return _play(KIND_STORY, title, story_resource, story_balloon_scene)


# Starts a non-blocking radio bark when no other PhaseLag dialogue is active.
func play_bark(title: StringName) -> bool:
	return _play(KIND_BARK, title, bark_resource, radio_balloon_scene)


# Reports whether callers must wait before starting a critical story title.
func is_busy() -> bool:
	return _active_resource != null


# Reports whether the active authored balloon owns the gameplay pause.
func is_story_active() -> bool:
	return _active_kind == KIND_STORY and _active_resource != null


# Routes one validated title into Dialogue Manager's authored balloon API.
func _play(kind: StringName, title: StringName, resource: DialogueResource, balloon_scene: PackedScene) -> bool:
	if title.is_empty() or is_busy():
		return false
	if not resource.titles.has(String(title)):
		push_error("PhaseDialogueRouter: unknown %s title '%s'" % [kind, title])
		return false
	_active_kind = kind
	_active_title = title
	_active_resource = resource
	_manager_ended = false
	_balloon_closed = false
	_active_balloon = _dialogue_manager.show_dialogue_balloon_scene(balloon_scene, resource, String(title)) as Node
	assert(_active_balloon != null, "PhaseDialogueRouter failed to create the authored balloon")
	assert(_active_balloon.has_signal(&"conversation_closed"), "PhaseDialogueRouter requires PhaseDialogueBalloon.conversation_closed")
	_active_balloon.connect(&"conversation_closed", _on_active_balloon_closed.bind(_active_balloon), CONNECT_ONE_SHOT)
	return true


# Records Dialogue Manager END while the authored balloon completes its exit animation.
func _on_dialogue_ended(resource: DialogueResource) -> void:
	if resource != _active_resource:
		return
	_manager_ended = true
	_finish_active_dialogue_if_ready()


# Records the matching authored balloon's completed exit animation.
func _on_active_balloon_closed(balloon: Node) -> void:
	if balloon != _active_balloon:
		return
	_balloon_closed = true
	_finish_active_dialogue_if_ready()


# Releases the anti-reentry lock only after both data and presentation have ended.
func _finish_active_dialogue_if_ready() -> void:
	if not _manager_ended or not _balloon_closed:
		return
	var completed_kind := _active_kind
	var completed_title := _active_title
	_active_resource = null
	_active_kind = &""
	_active_title = &""
	_active_balloon = null
	_manager_ended = false
	_balloon_closed = false
	dialogue_finished.emit(completed_kind, completed_title)
	if completed_kind == KIND_STORY:
		story_finished.emit(completed_title)
	else:
		bark_finished.emit(completed_title)
