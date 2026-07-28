class_name PhaseDialogueBalloon
extends CanvasLayer
## Presents one Dialogue Manager conversation through a persistent authored surface.

signal conversation_closed

const SILENT_BLIP_CHARACTERS := " \t\r\n，。！？；：、…—（）【】《》“”‘’.,!?;:-"

@export var pause_game: bool = false
@export var will_block_other_input: bool = false
@export var auto_advance: bool = false
@export_range(0.5, 5.0, 0.1, "suffix:s") var minimum_auto_delay: float = 1.6
@export_range(0.01, 0.08, 0.005, "suffix:s") var auto_delay_per_character: float = 0.025
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

var dialogue_resource: DialogueResource
var temporary_game_states: Array = []
var dialogue_line: DialogueLine:
	set(value):
		dialogue_line = value
		if value == null:
			_close_conversation()
		else:
			_apply_dialogue_line()

var _waiting_for_input := false
var _pause_applied := false
var _paused_before := false
var _line_loading := false
var _conversation_open := false
var _conversation_closing := false
var _low_flash_mode := false
var _last_blip_index := -2

@onready var balloon: Control = %Balloon
@onready var character_label: Label = %CharacterLabel
@onready var dialogue_label: ProjectDialogueLabel = %DialogueLabel
@onready var responses_menu: ProjectDialogueResponsesMenu = %ResponsesMenu
@onready var progress_hint: Label = %ProgressHint
@onready var speaker_line: ColorRect = %SpeakerLine
@onready var signal_wave: Line2D = %SignalWave
@onready var typing_audio: AudioStreamPlayer = %TypingAudio
@onready var balloon_animator: AnimationPlayer = %BalloonAnimator
@onready var wave_animator: AnimationPlayer = %WaveAnimator


# Keeps the authored surface hidden until Dialogue Manager starts a title.
func _ready() -> void:
	_low_flash_mode = bool(SettingsModule.instance.get_value("low_flash_mode", false)) if SettingsModule.instance != null else false
	responses_menu.response_selected.connect(_on_response_selected)
	dialogue_label.spoke.connect(_on_dialogue_spoke)
	responses_menu.next_action = next_action
	responses_menu.hide()
	progress_hint.hide()
	balloon.hide()


# Starts one Dialogue Manager title and owns the tree pause for the full conversation.
func start(resource: DialogueResource, title: String = "", extra_game_states: Array = []) -> void:
	assert(resource != null, "PhaseDialogueBalloon.start requires a DialogueResource")
	dialogue_resource = resource
	temporary_game_states = [self] + extra_game_states
	if pause_game:
		_paused_before = get_tree().paused
		get_tree().paused = true
		_pause_applied = true
	dialogue_line = await dialogue_resource.get_next_dialogue_line(title, temporary_game_states)


# Prevents an interrupted story balloon from leaving gameplay paused.
func _exit_tree() -> void:
	_restore_pause()


# Consumes story input while allowing radio barks to remain transparent.
func _unhandled_input(event: InputEvent) -> void:
	if not balloon.visible:
		return
	if auto_advance and not will_block_other_input:
		return
	if event.is_action_pressed(next_action) or event.is_action_pressed(skip_action):
		_consume_advance()
		get_viewport().set_input_as_handled()
		return
	if will_block_other_input:
		get_viewport().set_input_as_handled()


# Replaces one line in place, then reveals it without moving or fading the conversation surface.
func _apply_dialogue_line() -> void:
	var line := dialogue_line
	_line_loading = true
	_waiting_for_input = false
	_last_blip_index = -2
	progress_hint.hide()
	responses_menu.hide()
	responses_menu.responses = []
	balloon_animator.stop()
	character_label.visible = not line.character.is_empty()
	character_label.text = tr(line.character, "dialogue")
	_apply_speaker_palette(line.character)
	dialogue_label.visible_characters = 0
	dialogue_label.visible_ratio = 0.0
	dialogue_label.dialogue_line = line
	if not _conversation_open:
		balloon.show()
		await get_tree().process_frame
		await _play_balloon_animation(&"conversation_in")
		if not is_instance_valid(self) or dialogue_line != line:
			return
		_conversation_open = true
	_line_loading = false
	wave_animator.play(&"pulse_low_flash" if _low_flash_mode else &"pulse")
	dialogue_label.type_out()
	if dialogue_label.is_typing:
		await dialogue_label.finished_typing
	if not is_instance_valid(self) or dialogue_line != line or _conversation_closing:
		return
	_present_completed_line(line)


# Presents responses, auto timing, or the small authored continue arrow after typing.
func _present_completed_line(line: DialogueLine) -> void:
	if not line.responses.is_empty():
		responses_menu.responses = line.responses
		responses_menu.show()
		return
	if auto_advance or not line.time.is_empty():
		var wait_seconds := _resolve_auto_delay(line)
		await get_tree().create_timer(wait_seconds, true).timeout
		if is_instance_valid(self) and dialogue_line == line and not _conversation_closing:
			_advance(line.next_id)
		return
	_waiting_for_input = true
	progress_hint.show()
	balloon_animator.play(&"waiting_low_flash" if _low_flash_mode else &"waiting")
	balloon.grab_focus()


# Resolves explicit Dialogue Manager timing before using the radio fallback duration.
func _resolve_auto_delay(line: DialogueLine) -> float:
	if not line.time.is_empty() and line.time != "auto":
		return maxf(line.time.to_float(), 0.0)
	return maxf(minimum_auto_delay, float(dialogue_label.get_display_character_count()) * auto_delay_per_character)


# Requests the next Dialogue Manager line without closing the conversation surface.
func _advance(next_id: String) -> void:
	if _line_loading or _conversation_closing or dialogue_line == null:
		return
	_line_loading = true
	_waiting_for_input = false
	progress_hint.hide()
	responses_menu.hide()
	balloon_animator.stop()
	dialogue_label.visible_characters = 0
	dialogue_label.visible_ratio = 0.0
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


# Completes active typing on the first confirmation and advances on the second.
func _consume_advance() -> void:
	if _line_loading or _conversation_closing:
		return
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
		return
	if _waiting_for_input and dialogue_line != null and dialogue_line.responses.is_empty():
		_advance(dialogue_line.next_id)


# Routes mouse confirmation through the same two-step advance path.
func _on_balloon_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_consume_advance()
		get_viewport().set_input_as_handled()


# Advances through the exact Dialogue Manager branch selected by the player.
func _on_response_selected(response: DialogueResponse) -> void:
	_advance(response.next_id)


# Plays a restrained authored blip for every second visible non-punctuation glyph.
func _on_dialogue_spoke(letter: String, letter_index: int, _speed: float) -> void:
	if letter.is_empty() or SILENT_BLIP_CHARACTERS.contains(letter):
		return
	if letter_index - _last_blip_index < 2:
		return
	_last_blip_index = letter_index
	typing_audio.play()


# Fades the authored surface once after Dialogue Manager reaches END.
func _close_conversation() -> void:
	if _conversation_closing:
		return
	_conversation_closing = true
	_line_loading = true
	_waiting_for_input = false
	progress_hint.hide()
	responses_menu.hide()
	balloon_animator.stop()
	wave_animator.stop()
	if _conversation_open:
		await _play_balloon_animation(&"conversation_out")
	balloon.hide()
	_restore_pause()
	conversation_closed.emit()
	queue_free()


# Applies the two timeline temperatures to authored line and waveform nodes.
func _apply_speaker_palette(character_name: String) -> void:
	var accent := Color(1.0, 0.58, 0.24, 0.94) if character_name.contains("星遥") else Color(0.35, 0.94, 0.86, 0.94)
	if character_name.contains("旁白") or character_name.is_empty():
		accent = Color(0.72, 0.82, 0.8, 0.82)
	speaker_line.color = accent
	var wave_accent := accent
	wave_accent.a = 0.48 if _low_flash_mode else 0.82
	signal_wave.default_color = wave_accent
	character_label.modulate = Color(accent.r, accent.g, accent.b, 1.0)


# Plays one required animation authored in the balloon scene.
func _play_balloon_animation(animation_name: StringName) -> void:
	assert(balloon_animator.has_animation(animation_name), "PhaseDialogueBalloon is missing authored animation '%s'" % animation_name)
	balloon_animator.play(animation_name)
	await balloon_animator.animation_finished


# Restores exactly the pause state that existed before a blocking story began.
func _restore_pause() -> void:
	if not _pause_applied:
		return
	get_tree().paused = _paused_before
	_pause_applied = false
