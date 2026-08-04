class_name EchoChaseNarrativePresenter
extends Node
## Owns red-text memories, Keeper balloons, and the two ending tableaux.

const NORMAL_KEEPER_LINES := [
	"ENDING_NORMAL_KEEPER_1",
	"ENDING_NORMAL_KEEPER_2",
	"ENDING_NORMAL_KEEPER_3",
]
const NORMAL_RIFT_LINES := [
	"ENDING_NORMAL_RIFT_1",
	"ENDING_NORMAL_RIFT_2",
	"ENDING_NORMAL_RIFT_3",
	"ENDING_NORMAL_RIFT_4",
	"ENDING_NORMAL_RIFT_5",
	"ENDING_NORMAL_RIFT_6",
]
const TRUE_ACCEPTANCE_LINES := [
	"ENDING_TRUE_ACCEPTANCE_1",
	"ENDING_TRUE_ACCEPTANCE_2",
	"ENDING_TRUE_ACCEPTANCE_3",
	"ENDING_TRUE_ACCEPTANCE_4",
	"ENDING_TRUE_ACCEPTANCE_5",
	"ENDING_TRUE_ACCEPTANCE_6",
	"ENDING_TRUE_ACCEPTANCE_7",
]
const TRUE_TRACE_LINES := [
	"ENDING_TRUE_TRACE_1",
	"ENDING_TRUE_TRACE_2",
]
const TRUE_REUNION_LINES := [
	"ENDING_TRUE_REUNION_1",
	"ENDING_TRUE_REUNION_2",
	"ENDING_TRUE_REUNION_3",
	"ENDING_TRUE_REUNION_4",
	"ENDING_TRUE_REUNION_5",
]
const TRUE_EPILOGUE_LINES := [
	"ENDING_TRUE_EPILOGUE_1",
	"ENDING_TRUE_EPILOGUE_2",
]
const MEMORY_JITTER_BBCODE := "[jit2 scale=2.0 freq=18.0]%s[]"

@export var keeper_dialogue_resource_zh: DialogueResource
@export var keeper_dialogue_resource_en: DialogueResource
@export_group("Text Timing")
@export_range(0.05, 1.0, 0.05) var text_fade_seconds := 0.22
@export_range(0.2, 3.0, 0.05) var opening_hold_seconds := 1.1
@export_range(0.2, 3.0, 0.05) var memory_hold_seconds := 0.9
@export_range(0.2, 3.0, 0.05) var ending_hold_seconds := 1.15

@onready var memory_layer: CanvasLayer = %MemoryLayer
@onready var memory_tag: Label = %MemoryTag
@onready var memory_text: RicherTextLabel = %MemoryText
@onready var story_balloon: ModularBalloon = %StoryBalloon
@onready var ending_layer: CanvasLayer = %EndingLayer
@onready var ending_flash: ColorRect = %EndingFlash
@onready var normal_ending_text: Label = %NormalEndingText
@onready var true_ending_text: Label = %TrueEndingText
@onready var normal_group: Node2D = %NormalGroup
@onready var loop_player: Sprite2D = %LoopPlayer
@onready var loop_replacement_keeper: Sprite2D = %LoopReplacementKeeper
@onready var loop_old_keeper: Sprite2D = %LoopOldKeeper
@onready var loop_reborn_player: Sprite2D = %LoopRebornPlayer
@onready var loop_run_label: Label = %LoopRunLabel
@onready var loop_player_start: Marker2D = %LoopPlayerStart
@onready var loop_keeper_start: Marker2D = %LoopKeeperStart
@onready var loop_exit_target: Marker2D = %LoopExitTarget
@onready var loop_rebirth_target: Marker2D = %LoopRebirthTarget
@onready var normal_continue_button: Button = %NormalContinueButton
@onready var true_group: Node2D = %TrueGroup
@onready var past_figure: Sprite2D = %PastFigure
@onready var present_figure: Sprite2D = %PresentFigure
@onready var future_figure: Sprite2D = %FutureFigure
@onready var keeper_figure: Sprite2D = %KeeperFigure
@onready var merged_figure: Sprite2D = %MergedFigure
@onready var rewritten_hero: Sprite2D = %RewrittenHero
@onready var lia_figure: Sprite2D = %LiaFigure
@onready var future_trace: Line2D = %FutureTrace
@onready var third_path: Line2D = %ThirdPath
@onready var true_run_label: Label = %TrueRunLabel
@onready var past_start: Marker2D = %PastStart
@onready var present_start: Marker2D = %PresentStart
@onready var future_start: Marker2D = %FutureStart
@onready var keeper_start: Marker2D = %KeeperStart
@onready var merge_target: Marker2D = %MergeTarget
@onready var rewritten_hero_start: Marker2D = %RewrittenHeroStart
@onready var lia_start: Marker2D = %LiaStart
@onready var true_exit_target: Marker2D = %TrueExitTarget
@onready var lia_exit_target: Marker2D = %LiaExitTarget
@onready var true_return_button: Button = %TrueReturnButton

var _sequence_active := false


# Hides all authored story surfaces until a sequence explicitly owns the screen.
func _ready() -> void:
	if keeper_dialogue_resource_zh == null or keeper_dialogue_resource_en == null:
		push_error("EchoChaseNarrativePresenter requires zh and en Keeper dialogue resources")
	memory_layer.visible = false
	ending_layer.visible = false
	memory_text.hide()
	normal_ending_text.hide()
	true_ending_text.hide()
	ending_flash.hide()
	normal_continue_button.hide()
	true_return_button.hide()


# Plays the localized opening command inside the same black-red memory surface.
func play_opening_run_card() -> void:
	if _sequence_active:
		push_error("EchoChaseNarrativePresenter cannot overlap story sequences")
		return
	_sequence_active = true
	memory_tag.hide()
	memory_layer.visible = true
	await _play_memory_lines(["STORY_RUN"], opening_hold_seconds)
	memory_layer.visible = false
	memory_tag.show()
	_sequence_active = false


# Pauses play and flashes a memory as centered red text instead of a dialogue balloon.
func play_memory_sequence(line_keys: Array, time_tag_key: String) -> void:
	if _sequence_active:
		push_error("EchoChaseNarrativePresenter cannot overlap story sequences")
		return
	if line_keys.is_empty():
		push_error("EchoChaseNarrativePresenter requires memory line keys")
		return
	_sequence_active = true
	var was_paused := _pause_world()
	memory_tag.text = tr(time_tag_key)
	memory_tag.show()
	memory_layer.visible = true
	await _play_memory_lines(line_keys, memory_hold_seconds)
	memory_layer.visible = false
	_restore_world(was_paused)
	_sequence_active = false


# Plays only Keeper reactions through the existing Present Hub dialogue resource.
func play_keeper_dialogue(title: String) -> void:
	if _sequence_active:
		push_error("EchoChaseNarrativePresenter cannot overlap story sequences")
		return
	var keeper_dialogue_resource := _get_localized_keeper_dialogue_resource()
	if title.is_empty() or keeper_dialogue_resource == null:
		push_error("EchoChaseNarrativePresenter requires a valid Keeper dialogue title")
		return
	_sequence_active = true
	var was_paused := _pause_world()
	story_balloon.start(keeper_dialogue_resource, title, [self])
	await story_balloon.dialogue_ended
	_restore_world(was_paused)
	_sequence_active = false


# Selects the Keeper resource at playback time so pause-menu language changes apply immediately.
func _get_localized_keeper_dialogue_resource() -> DialogueResource:
	return keeper_dialogue_resource_zh if TranslationServer.get_locale().begins_with("zh") else keeper_dialogue_resource_en


# Plays the Keeper's false escape, the Rift's reveal, and the memory-wipe loop.
func play_normal_ending() -> void:
	var was_paused := _pause_world()
	_reset_normal_tableau()
	ending_layer.visible = true
	normal_group.show()
	await _play_lines(normal_ending_text, NORMAL_KEEPER_LINES, ending_hold_seconds)
	var exit_tween := _new_cinematic_tween()
	exit_tween.tween_interval(0.25)
	exit_tween.set_parallel(true)
	exit_tween.tween_property(loop_old_keeper, "position", loop_exit_target.position, 1.2)
	exit_tween.tween_property(loop_old_keeper, "modulate:a", 0.0, 1.2)
	exit_tween.tween_property(loop_player, "modulate:a", 0.0, 0.8).set_delay(0.3)
	exit_tween.tween_property(loop_replacement_keeper, "modulate:a", 1.0, 0.8).set_delay(0.3)
	await exit_tween.finished
	await _play_lines(normal_ending_text, NORMAL_RIFT_LINES, ending_hold_seconds)
	await _play_memory_wash()
	loop_reborn_player.show()
	loop_run_label.show()
	var rebirth_tween := _new_cinematic_tween()
	rebirth_tween.set_parallel(true)
	rebirth_tween.tween_property(loop_reborn_player, "modulate:a", 1.0, 0.55)
	rebirth_tween.tween_property(loop_run_label, "modulate:a", 1.0, 0.55)
	await rebirth_tween.finished
	normal_continue_button.show()
	normal_continue_button.grab_focus()
	await normal_continue_button.pressed
	ending_layer.visible = false
	_restore_world(was_paused)


# Plays acceptance, the backward Future Trace, reunion, and the third-path escape.
func play_true_ending() -> void:
	var was_paused := _pause_world()
	_reset_true_tableau()
	ending_layer.visible = true
	true_group.show()
	var merge_tween := _new_cinematic_tween()
	merge_tween.set_parallel(true)
	for figure in [past_figure, present_figure, future_figure, keeper_figure]:
		merge_tween.tween_property(figure, "position", merge_target.position, 1.0)
		merge_tween.tween_property(figure, "modulate:a", 0.0, 1.0)
	await merge_tween.finished
	merged_figure.show()
	var merged_tween := _new_cinematic_tween()
	merged_tween.tween_property(merged_figure, "modulate:a", 1.0, 0.35)
	await merged_tween.finished
	await _play_lines(true_ending_text, TRUE_ACCEPTANCE_LINES, ending_hold_seconds)
	future_trace.show()
	true_run_label.show()
	var trace_tween := _new_cinematic_tween()
	trace_tween.set_parallel(true)
	trace_tween.tween_property(future_trace, "scale:x", 1.0, 1.0)
	trace_tween.tween_property(true_run_label, "modulate:a", 1.0, 0.45)
	await trace_tween.finished
	await _play_lines(true_ending_text, TRUE_TRACE_LINES, ending_hold_seconds)
	merged_figure.hide()
	rewritten_hero.show()
	lia_figure.show()
	await _play_lines(true_ending_text, TRUE_REUNION_LINES, ending_hold_seconds)
	third_path.show()
	var escape_tween := _new_cinematic_tween()
	escape_tween.set_parallel(true)
	escape_tween.tween_property(rewritten_hero, "position", true_exit_target.position, 1.4)
	escape_tween.tween_property(lia_figure, "position", lia_exit_target.position, 1.4)
	escape_tween.tween_property(rewritten_hero, "modulate:a", 0.0, 1.4)
	escape_tween.tween_property(lia_figure, "modulate:a", 0.0, 1.4)
	await escape_tween.finished
	await _play_lines(true_ending_text, TRUE_EPILOGUE_LINES, ending_hold_seconds)
	true_return_button.show()
	true_return_button.grab_focus()
	await true_return_button.pressed
	ending_layer.visible = false
	_restore_world(was_paused)


# Serializes translated lines through one centered label with a short fade rhythm.
func _play_lines(label: Label, line_keys: Array, hold_seconds: float) -> void:
	for line_key in line_keys:
		label.text = tr(String(line_key))
		_set_alpha(label, 0.0)
		label.show()
		var tween := _new_cinematic_tween()
		tween.tween_property(label, "modulate:a", 1.0, text_fade_seconds)
		tween.tween_interval(hold_seconds)
		tween.tween_property(label, "modulate:a", 0.0, text_fade_seconds)
		await tween.finished
	label.hide()


# Serializes translated memory text through RichText2's authored jitter effect.
func _play_memory_lines(line_keys: Array, hold_seconds: float) -> void:
	for line_key in line_keys:
		memory_text.bbcode = MEMORY_JITTER_BBCODE % tr(String(line_key))
		_set_alpha(memory_text, 0.0)
		memory_text.show()
		var tween := _new_cinematic_tween()
		tween.tween_property(memory_text, "modulate:a", 1.0, text_fade_seconds)
		tween.tween_interval(hold_seconds)
		tween.tween_property(memory_text, "modulate:a", 0.0, text_fade_seconds)
		await tween.finished
	memory_text.hide()


# Flashes the authored pale surface once as the Rift clears both surviving selves.
func _play_memory_wash() -> void:
	ending_flash.show()
	_set_alpha(ending_flash, 0.0)
	var tween := _new_cinematic_tween()
	tween.tween_property(ending_flash, "modulate:a", 0.92, 0.16)
	tween.tween_interval(0.12)
	tween.tween_property(ending_flash, "modulate:a", 0.0, 0.55)
	await tween.finished
	ending_flash.hide()


# Freezes gameplay and the false deadline while a story surface owns the screen.
func _pause_world() -> bool:
	var was_paused := get_tree().paused
	get_tree().paused = true
	EchoTimeline.pause_run_countdown()
	return was_paused


# Restores the exact pause and countdown state that preceded the story sequence.
func _restore_world(was_paused: bool) -> void:
	get_tree().paused = was_paused
	if not was_paused:
		EchoTimeline.resume_run_countdown()


# Restores every normal-ending figure from authored marker positions.
func _reset_normal_tableau() -> void:
	true_group.hide()
	normal_group.show()
	normal_continue_button.hide()
	normal_ending_text.hide()
	true_ending_text.hide()
	ending_flash.hide()
	loop_player.position = loop_player_start.position
	loop_replacement_keeper.position = loop_player_start.position
	loop_old_keeper.position = loop_keeper_start.position
	loop_reborn_player.position = loop_rebirth_target.position
	_set_alpha(loop_player, 1.0)
	_set_alpha(loop_replacement_keeper, 0.0)
	_set_alpha(loop_old_keeper, 1.0)
	_set_alpha(loop_reborn_player, 0.0)
	_set_alpha(loop_run_label, 0.0)
	loop_run_label.text = tr("STORY_RUN")
	loop_player.show()
	loop_replacement_keeper.show()
	loop_old_keeper.show()
	loop_reborn_player.hide()
	loop_run_label.hide()


# Restores every true-ending figure and path from authored marker positions.
func _reset_true_tableau() -> void:
	normal_group.hide()
	true_group.show()
	true_return_button.hide()
	normal_ending_text.hide()
	true_ending_text.hide()
	ending_flash.hide()
	past_figure.position = past_start.position
	present_figure.position = present_start.position
	future_figure.position = future_start.position
	keeper_figure.position = keeper_start.position
	merged_figure.position = merge_target.position
	rewritten_hero.position = rewritten_hero_start.position
	lia_figure.position = lia_start.position
	for figure in [past_figure, present_figure, future_figure, keeper_figure]:
		figure.show()
		_set_alpha(figure, 1.0)
	_set_alpha(merged_figure, 0.0)
	_set_alpha(rewritten_hero, 1.0)
	_set_alpha(lia_figure, 1.0)
	_set_alpha(true_run_label, 0.0)
	true_run_label.text = tr("STORY_RUN")
	merged_figure.hide()
	rewritten_hero.hide()
	lia_figure.hide()
	future_trace.scale.x = 0.0
	future_trace.hide()
	third_path.hide()
	true_run_label.hide()


# Creates one pause-safe tween bound to the authored presenter.
func _new_cinematic_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


# Changes only opacity while preserving each authored tint.
func _set_alpha(item: CanvasItem, alpha: float) -> void:
	var color := item.modulate
	color.a = alpha
	item.modulate = color
