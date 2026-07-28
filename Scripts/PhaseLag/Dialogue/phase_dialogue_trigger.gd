class_name PhaseDialogueTrigger
extends Area2D
## Starts one authored PhaseLag bark or story title when a player reaches a landmark.

@export_enum("story", "bark") var dialogue_kind: String = "bark"
@export var dialogue_title: StringName = &""
@export var one_shot: bool = true

var _pending := false
var _consumed := false


# Validates the authored title and listens for player entry without creating UI nodes.
func _ready() -> void:
	assert(not dialogue_title.is_empty(), "PhaseDialogueTrigger requires an authored dialogue_title")
	body_entered.connect(_on_body_entered)


# Queues one dialogue attempt and ignores unrelated physics bodies.
func _on_body_entered(body: Node2D) -> void:
	if _consumed or _pending or not body.is_in_group("phase_players"):
		return
	_pending = true
	_play_when_available()


# Waits for the active balloon to finish before routing this trigger through Dialogue Manager.
func _play_when_available() -> void:
	var router := PhaseDialogueRouter.instance
	assert(router != null, "PhaseDialogueTrigger requires the authored PhaseDialogueRouter")
	while is_inside_tree():
		while router.is_busy():
			await router.dialogue_finished
		var started := router.play_story(dialogue_title) if dialogue_kind == "story" else router.play_bark(dialogue_title)
		if started:
			if one_shot:
				_consumed = true
			_pending = false
			return
		if not router.is_busy():
			push_error("PhaseDialogueTrigger could not start authored title '%s'" % dialogue_title)
			_pending = false
			return
	_pending = false
