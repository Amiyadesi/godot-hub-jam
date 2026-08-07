class_name DelayTraceNarrativePresenter
extends Node
## Owns red-text memories and the two localized ending tableaux.

const MEMORY_JITTER_BBCODE := "[jit2 scale=2.0 freq=18.0]%s[]"

@export_group("Dialogue")
@export var ending_dialogue_resource_zh: DialogueResource
@export var ending_dialogue_resource_en: DialogueResource

@export_group("Text Timing")
@export_range(0.05, 1.0, 0.05) var text_fade_seconds := 0.22
@export_range(0.2, 3.0, 0.05) var opening_hold_seconds := 1.1
@export_range(0.2, 3.0, 0.05) var memory_hold_seconds := 0.9
@export_range(0.2, 3.0, 0.05) var ending_hold_seconds := 1.15

@onready var memory_layer: CanvasLayer = %MemoryLayer
@onready var memory_tag: Label = %MemoryTag
@onready var memory_text: RicherTextLabel = %MemoryText
@onready var opening_runner: AnimatedSprite2D = %OpeningRunner
@onready var ending_layer: CanvasLayer = %EndingLayer
@onready var ending_flash: ColorRect = %EndingFlash
@onready var ending_dim: ColorRect = %EndingDim
@onready var normal_ending_text: RicherTextLabel = %NormalEndingText
@onready var true_ending_text: RicherTextLabel = %TrueEndingText
@onready var normal_ending_title: RicherTextLabel = %NormalEndingTitle
@onready var normal_ending_hint: RicherTextLabel = %NormalEndingHint
@onready var normal_group: Node2D = %NormalGroup
@onready var player_bindings: Node2D = %PlayerBindings
@onready var normal_exit_particles: GPUParticles2D = %NormalExitParticles
@onready var identity_pulse_particles: GPUParticles2D = %IdentityPulseParticles
@onready var loop_player: Sprite2D = %LoopPlayer
@onready var loop_replacement_keeper: Sprite2D = %LoopReplacementKeeper
@onready var loop_old_keeper: Sprite2D = %LoopOldKeeper
@onready var loop_keeper_animation_player: AnimationPlayer = %LoopKeeperAnimationPlayer
@onready var loop_reborn_player: Sprite2D = %LoopRebornPlayer
@onready var loop_run_label: Label = %LoopRunLabel
@onready var loop_player_start: Marker2D = %LoopPlayerStart
@onready var loop_keeper_start: Marker2D = %LoopKeeperStart
@onready var loop_keeper_talk_target: Marker2D = %LoopKeeperTalkTarget
@onready var loop_exit_target: Marker2D = %LoopExitTarget
@onready var loop_rebirth_target: Marker2D = %LoopRebirthTarget
@onready var normal_continue_button: Button = %NormalContinueButton
@onready var true_group: Node2D = %TrueGroup
@onready var past_figure: Sprite2D = %PastFigure
@onready var present_figure: Sprite2D = %PresentFigure
@onready var future_figure: Sprite2D = %FutureFigure
@onready var keeper_figure: Sprite2D = %KeeperFigure
@onready var true_keeper_animation_player: AnimationPlayer = %TrueKeeperAnimationPlayer
@onready var past_merge_trail: GPUParticles2D = %PastMergeTrail
@onready var present_merge_trail: GPUParticles2D = %PresentMergeTrail
@onready var future_merge_trail: GPUParticles2D = %FutureMergeTrail
@onready var keeper_merge_trail: GPUParticles2D = %KeeperMergeTrail
@onready var merge_burst_particles: GPUParticles2D = %MergeBurstParticles
@onready var merged_figure: Sprite2D = %MergedFigure
@onready var rewritten_hero: Sprite2D = %RewrittenHero
@onready var lia_figure: Sprite2D = %LiaFigure
@onready var future_trace: Line2D = %FutureTrace
@onready var trace_pulse_particles: GPUParticles2D = %TracePulseParticles
@onready var third_path: Line2D = %ThirdPath
@onready var third_path_particles: GPUParticles2D = %ThirdPathParticles
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
var _active_ending_dialogue_resource: DialogueResource
var _ending_uses_chinese := false


# Hides all authored story surfaces until a sequence explicitly owns the screen.
func _ready() -> void:
	if ending_dialogue_resource_zh == null or ending_dialogue_resource_en == null:
		push_error("DelayTraceNarrativePresenter requires zh and en ending dialogue resources")
		return
	memory_layer.visible = false
	opening_runner.hide()
	ending_layer.visible = false
	memory_text.hide()
	normal_ending_text.hide()
	true_ending_text.hide()
	normal_ending_title.hide()
	normal_ending_hint.hide()
	ending_flash.hide()
	_set_alpha(ending_dim, 0.0)
	normal_continue_button.hide()
	true_return_button.hide()


# Locks both ending tableaux to the language selected once by the scene controller.
func select_dialogue_language(use_chinese: bool) -> void:
	if _active_ending_dialogue_resource != null:
		push_error("DelayTraceNarrativePresenter dialogue language was already selected")
		return
	_ending_uses_chinese = use_chinese
	_active_ending_dialogue_resource = (
		ending_dialogue_resource_zh if use_chinese else ending_dialogue_resource_en
	)


# Plays the localized command while a separate silhouette reaches the real spawn position.
func play_opening_run_card(target_screen_position: Vector2) -> void:
	if _sequence_active:
		push_error("DelayTraceNarrativePresenter cannot overlap story sequences")
		return
	_sequence_active = true
	memory_tag.hide()
	memory_layer.visible = true
	opening_runner.position = Vector2(-64.0, target_screen_position.y)
	opening_runner.show()
	opening_runner.play(&"run")
	memory_text.bbcode = MEMORY_JITTER_BBCODE % tr("STORY_RUN")
	_set_alpha(memory_text, 0.0)
	memory_text.show()
	var tween := _new_cinematic_tween()
	tween.set_parallel(true)
	tween.tween_property(opening_runner, "position", target_screen_position, opening_hold_seconds)
	tween.tween_property(memory_text, "modulate:a", 1.0, text_fade_seconds)
	tween.tween_property(memory_text, "modulate:a", 0.0, text_fade_seconds).set_delay(
		maxf(opening_hold_seconds - text_fade_seconds, 0.0)
	)
	await tween.finished
	opening_runner.hide()
	opening_runner.stop()
	memory_text.hide()
	memory_layer.visible = false
	memory_tag.show()
	_sequence_active = false


# Pauses play and flashes a memory as centered red text instead of a dialogue balloon.
func play_memory_sequence(line_keys: Array, time_tag_key: String) -> void:
	if _sequence_active:
		push_error("DelayTraceNarrativePresenter cannot overlap story sequences")
		return
	if line_keys.is_empty():
		push_error("DelayTraceNarrativePresenter requires memory line keys")
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


# Plays the Keeper's left-to-right escape, the Rift's reveal, and the memory-wipe loop.
func play_normal_ending() -> void:
	var keeper_lines := await _read_ending_lines(&"normal_keeper")
	var rift_lines := await _read_ending_lines(&"normal_rift")
	var ending_title := await _read_ending_text(&"normal_title")
	var ending_hint := await _read_ending_text(&"normal_hint")
	var run_text := await _read_ending_text(&"normal_run")
	var continue_text := await _read_ending_text(&"normal_continue")
	var was_paused := _pause_world()
	_reset_normal_tableau()
	loop_run_label.text = run_text
	normal_continue_button.text = continue_text
	ending_layer.visible = true
	normal_group.show()
	player_bindings.show()
	loop_keeper_animation_player.play(&"run")
	var binding_tween := _new_cinematic_tween()
	binding_tween.set_parallel(true)
	binding_tween.tween_property(player_bindings, "modulate:a", 1.0, 0.45)
	binding_tween.tween_property(player_bindings, "scale", Vector2(1.08, 1.08), 0.45)
	await binding_tween.finished
	var keeper_entry := _new_cinematic_tween()
	keeper_entry.tween_property(loop_old_keeper, "position", loop_keeper_talk_target.position, 1.1)
	await keeper_entry.finished
	loop_keeper_animation_player.play(&"idle")
	await _play_lines(normal_ending_text, keeper_lines, ending_hold_seconds)
	normal_exit_particles.amount_ratio = 0.25 if _uses_low_flash_mode() else 1.0
	normal_exit_particles.restart()
	normal_exit_particles.emitting = true
	loop_keeper_animation_player.play(&"run")
	var exit_tween := _new_cinematic_tween()
	exit_tween.tween_interval(0.25)
	exit_tween.tween_property(loop_old_keeper, "position", loop_exit_target.position, 1.2)
	exit_tween.parallel().tween_property(loop_old_keeper, "modulate:a", 0.0, 1.2)
	await exit_tween.finished
	normal_exit_particles.emitting = false
	loop_replacement_keeper.scale = Vector2(6.2, 6.2)
	if not _uses_low_flash_mode():
		identity_pulse_particles.restart()
		identity_pulse_particles.emitting = true
	var handoff_tween := _new_cinematic_tween()
	handoff_tween.set_parallel(true)
	handoff_tween.tween_property(loop_player, "modulate:a", 0.0, 0.8).set_delay(0.3)
	handoff_tween.tween_property(loop_replacement_keeper, "modulate:a", 1.0, 0.8)
	handoff_tween.tween_property(loop_replacement_keeper, "scale", Vector2(8.0, 8.0), 0.8)
	await handoff_tween.finished
	var dim_tween := _new_cinematic_tween()
	dim_tween.set_parallel(true)
	dim_tween.tween_property(ending_dim, "modulate:a", 0.82, 1.0)
	dim_tween.tween_property(normal_group, "modulate", Color(0.34, 0.38, 0.42, 1.0), 1.0)
	await dim_tween.finished
	await _play_lines(normal_ending_text, rift_lines, ending_hold_seconds)
	loop_player.hide()
	loop_replacement_keeper.hide()
	player_bindings.hide()
	loop_reborn_player.show()
	loop_run_label.show()
	var rebirth_tween := _new_cinematic_tween()
	rebirth_tween.set_parallel(true)
	rebirth_tween.tween_property(loop_reborn_player, "modulate:a", 1.0, 0.55)
	rebirth_tween.tween_property(loop_run_label, "modulate:a", 1.0, 0.55)
	await rebirth_tween.finished
	normal_ending_title.bbcode = ending_title
	normal_ending_hint.bbcode = ending_hint
	normal_ending_title.show()
	normal_ending_hint.show()
	normal_continue_button.show()
	normal_continue_button.grab_focus()
	await normal_continue_button.pressed
	ending_layer.visible = false
	normal_exit_particles.emitting = false
	_restore_world(was_paused)


# Plays acceptance, the backward Future Trace, reunion, and the third-path escape.
func play_true_ending() -> void:
	var acceptance_lines := await _read_ending_lines(&"true_acceptance")
	var trace_lines := await _read_ending_lines(&"true_trace")
	var reunion_lines := await _read_ending_lines(&"true_reunion")
	var epilogue_lines := await _read_ending_lines(&"true_epilogue")
	var run_text := await _read_ending_text(&"true_run")
	var return_text := await _read_ending_text(&"true_return")
	var was_paused := _pause_world()
	_reset_true_tableau()
	true_run_label.text = run_text
	true_return_button.text = return_text
	ending_layer.visible = true
	true_group.show()
	true_keeper_animation_player.play(&"run")
	var merge_figures: Array[Sprite2D] = [past_figure, present_figure, future_figure, keeper_figure]
	var merge_trails: Array[GPUParticles2D] = [
		past_merge_trail,
		present_merge_trail,
		future_merge_trail,
		keeper_merge_trail,
	]
	var merge_tween := _new_cinematic_tween()
	merge_tween.set_parallel(true)
	for index in range(merge_figures.size()):
		var figure := merge_figures[index]
		var trail := merge_trails[index]
		trail.amount_ratio = 0.25 if _uses_low_flash_mode() else 1.0
		trail.restart()
		trail.emitting = true
		merge_tween.tween_property(figure, "position", merge_target.position, 1.0)
		merge_tween.tween_property(figure, "modulate:a", 0.0, 1.0)
		merge_tween.tween_property(trail, "position", merge_target.position, 1.0)
	await merge_tween.finished
	true_keeper_animation_player.stop()
	for trail in merge_trails:
		trail.emitting = false
	if not _uses_low_flash_mode():
		merge_burst_particles.restart()
		merge_burst_particles.emitting = true
	await _play_ending_flash(Color(1.0, 0.78, 0.24, 1.0), 0.72)
	merged_figure.show()
	var merged_tween := _new_cinematic_tween()
	merged_tween.tween_property(merged_figure, "modulate:a", 1.0, 0.35)
	await merged_tween.finished
	await _play_lines(true_ending_text, acceptance_lines, ending_hold_seconds)
	future_trace.show()
	true_run_label.show()
	if not _uses_low_flash_mode():
		trace_pulse_particles.restart()
		trace_pulse_particles.emitting = true
	var trace_tween := _new_cinematic_tween()
	trace_tween.set_parallel(true)
	trace_tween.tween_property(future_trace, "scale:x", 1.0, 1.0)
	trace_tween.tween_property(true_run_label, "modulate:a", 1.0, 0.45)
	await trace_tween.finished
	await _play_lines(true_ending_text, trace_lines, ending_hold_seconds)
	merged_figure.hide()
	rewritten_hero.show()
	lia_figure.show()
	await _play_lines(true_ending_text, reunion_lines, ending_hold_seconds)
	third_path.show()
	third_path_particles.amount_ratio = 0.25 if _uses_low_flash_mode() else 1.0
	third_path_particles.restart()
	third_path_particles.emitting = true
	var path_tween := _new_cinematic_tween()
	path_tween.set_parallel(true)
	path_tween.tween_property(future_trace, "modulate:a", 0.0, 0.55)
	path_tween.tween_property(third_path, "modulate:a", 1.0, 0.55)
	path_tween.tween_property(third_path, "width", 12.0, 0.55)
	await path_tween.finished
	future_trace.hide()
	var escape_tween := _new_cinematic_tween()
	escape_tween.set_parallel(true)
	escape_tween.tween_property(rewritten_hero, "position", true_exit_target.position, 1.4)
	escape_tween.tween_property(lia_figure, "position", lia_exit_target.position, 1.4)
	escape_tween.tween_property(rewritten_hero, "modulate:a", 0.0, 1.4)
	escape_tween.tween_property(lia_figure, "modulate:a", 0.0, 1.4)
	await escape_tween.finished
	await _play_lines(true_ending_text, epilogue_lines, ending_hold_seconds)
	true_return_button.show()
	true_return_button.grab_focus()
	await true_return_button.pressed
	ending_layer.visible = false
	third_path_particles.emitting = false
	_restore_world(was_paused)


# Serializes authored dialogue-resource lines through one centered RichText2 label.
func _play_lines(label: RicherTextLabel, lines: Array[String], hold_seconds: float) -> void:
	for line_text in lines:
		label.bbcode = line_text
		_set_alpha(label, 0.0)
		label.show()
		var tween := _new_cinematic_tween()
		tween.tween_property(label, "modulate:a", 1.0, text_fade_seconds)
		tween.tween_interval(hold_seconds)
		tween.tween_property(label, "modulate:a", 0.0, text_fade_seconds)
		await tween.finished
	label.hide()


# Reads one ending title sequentially from the language resource chosen at startup.
func _read_ending_lines(title: StringName, include_character := true) -> Array[String]:
	var lines: Array[String] = []
	if _active_ending_dialogue_resource == null:
		push_error("DelayTraceNarrativePresenter has no active ending dialogue resource")
		return lines
	var line: DialogueLine = await _active_ending_dialogue_resource.get_next_dialogue_line(
		String(title),
		[],
		DMConstants.MutationBehaviour.Skip
	)
	while line != null:
		lines.append(_format_ending_line(line, include_character))
		if line.next_id in [DMConstants.ID_NULL, DMConstants.ID_END, DMConstants.ID_END_CONVERSATION]:
			break
		line = await _active_ending_dialogue_resource.get_next_dialogue_line(
			line.next_id,
			[],
			DMConstants.MutationBehaviour.Skip
		)
	if lines.is_empty():
		push_error("DelayTraceNarrativePresenter found no lines for ending title '%s'" % title)
	return lines


# Reads one UI string from a single-line ending title without a speaker prefix.
func _read_ending_text(title: StringName) -> String:
	var lines := await _read_ending_lines(title, false)
	if lines.size() != 1:
		push_error("DelayTraceNarrativePresenter expected one line for ending title '%s'" % title)
		return ""
	return lines[0]


# Keeps speaker names in cinematic dialogue while matching the active language punctuation.
func _format_ending_line(line: DialogueLine, include_character: bool) -> String:
	if not include_character or line.character.is_empty():
		return line.text
	return "%s%s%s" % [line.character, "：" if _ending_uses_chinese else ": ", line.text]


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
	await _play_ending_flash(Color(0.78, 0.94, 1.0, 1.0), 0.92)


# Flashes one authored surface with a reduced peak and slower rhythm in low-flash mode.
func _play_ending_flash(color: Color, alpha: float) -> void:
	ending_flash.color = color
	ending_flash.show()
	_set_alpha(ending_flash, 0.0)
	var reduced := _uses_low_flash_mode()
	var peak_alpha := minf(alpha, 0.28) if reduced else alpha
	var tween := _new_cinematic_tween()
	tween.tween_property(ending_flash, "modulate:a", peak_alpha, 0.28 if reduced else 0.16)
	tween.tween_interval(0.05 if reduced else 0.12)
	tween.tween_property(ending_flash, "modulate:a", 0.0, 0.72 if reduced else 0.55)
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
	normal_group.modulate = Color.WHITE
	normal_continue_button.hide()
	normal_ending_text.hide()
	true_ending_text.hide()
	normal_ending_title.hide()
	normal_ending_hint.hide()
	ending_flash.hide()
	_set_alpha(ending_dim, 0.0)
	loop_player.position = loop_player_start.position
	loop_replacement_keeper.position = loop_player_start.position
	loop_old_keeper.position = loop_keeper_start.position
	loop_old_keeper.flip_h = false
	loop_reborn_player.position = loop_rebirth_target.position
	player_bindings.position = loop_player_start.position
	player_bindings.rotation = 0.0
	player_bindings.scale = Vector2.ONE
	loop_replacement_keeper.scale = Vector2(8.0, 8.0)
	loop_keeper_animation_player.play(&"idle")
	normal_exit_particles.emitting = false
	identity_pulse_particles.emitting = false
	_set_alpha(loop_player, 1.0)
	_set_alpha(loop_replacement_keeper, 0.0)
	_set_alpha(loop_old_keeper, 1.0)
	_set_alpha(loop_reborn_player, 0.0)
	_set_alpha(loop_run_label, 0.0)
	loop_player.show()
	loop_replacement_keeper.show()
	loop_old_keeper.show()
	player_bindings.hide()
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
	keeper_figure.flip_h = true
	merged_figure.position = merge_target.position
	rewritten_hero.position = rewritten_hero_start.position
	lia_figure.position = lia_start.position
	past_merge_trail.position = past_start.position
	present_merge_trail.position = present_start.position
	future_merge_trail.position = future_start.position
	keeper_merge_trail.position = keeper_start.position
	for figure in [past_figure, present_figure, future_figure, keeper_figure]:
		figure.show()
		_set_alpha(figure, 1.0)
	_set_alpha(merged_figure, 0.0)
	_set_alpha(rewritten_hero, 1.0)
	_set_alpha(lia_figure, 1.0)
	_set_alpha(true_run_label, 0.0)
	merged_figure.hide()
	rewritten_hero.hide()
	lia_figure.hide()
	future_trace.scale.x = 0.0
	_set_alpha(future_trace, 1.0)
	future_trace.hide()
	for trail in [past_merge_trail, present_merge_trail, future_merge_trail, keeper_merge_trail]:
		trail.emitting = false
	merge_burst_particles.emitting = false
	trace_pulse_particles.emitting = false
	third_path_particles.emitting = false
	third_path.width = 2.0
	_set_alpha(third_path, 0.0)
	third_path.hide()
	true_run_label.hide()
	true_keeper_animation_player.play(&"idle")


# Creates one pause-safe tween bound to the authored presenter.
func _new_cinematic_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


# Changes only opacity while preserving each authored tint.
func _set_alpha(item: CanvasItem, alpha: float) -> void:
	var color := item.modulate
	color.a = alpha
	item.modulate = color


# Reads the existing accessibility setting for ending flashes and dense particle bursts.
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
