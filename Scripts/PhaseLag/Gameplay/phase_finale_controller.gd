class_name PhaseFinaleController
extends Node2D
## Owns the non-playable fifth chapter through authored animation, camera, audio, and dialogue.

const CHAPTER: ChapterDefinition = preload("res://resources/phase_lag/chapters/chapter_05.tres")
const MENU_PATH: String = "res://Scenes/UI/Menu/menu.tscn"

@export var entry_transition: bool = false

@onready var dialogue_router: PhaseDialogueRouter = %PhaseDialogueRouter
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var chapter_transition: PhaseChapterTransition = %PhaseChapterTransition
@onready var menu_theme: AudioStreamPlayer = %MenuTheme
@onready var factory_ambient: AudioStreamPlayer = %FactoryAmbient
@onready var end_card: Control = %EndCard
@onready var return_button: Button = %ReturnButton


# Stops title audio before the authored finale sound bed enters the tree.
func _enter_tree() -> void:
	GameAudio.stop_music(0.0)


# Restarts the finale from its stable beginning and records no mid-scene state.
func _ready() -> void:
	assert(CHAPTER.flow_kind == ChapterDefinition.FLOW_FINALE, "PhaseFinaleController requires a finale chapter")
	get_tree().paused = false
	EntanglementBus.reset_queue(true)
	return_button.pressed.connect(_return_to_menu)
	menu_theme.finished.connect(_restart_stream.bind(menu_theme))
	factory_ambient.finished.connect(_restart_stream.bind(factory_ambient))
	menu_theme.play()
	factory_ambient.play()
	if entry_transition:
		chapter_transition.prepare_open("第五章 · 抵达")
	else:
		chapter_transition.hide_immediately()
	_store_finale_start()
	call_deferred("_run_finale")


# Plays the authored convergence, choice, separation, and last-signal sequence.
func _run_finale() -> void:
	if entry_transition:
		await chapter_transition.play_open("第五章 · 抵达")
		entry_transition = false
	animation_player.play(&"opening")
	await animation_player.animation_finished
	await _play_story_title(CHAPTER.opening_dialogue_title)
	if not is_instance_valid(self):
		return
	animation_player.play(&"separation")
	await animation_player.animation_finished
	await _play_story_title(CHAPTER.completion_dialogue_title)
	if not is_instance_valid(self):
		return
	animation_player.play(&"signal")
	await animation_player.animation_finished
	_complete_finale()


# Waits for one Dialogue Manager title to reach END before the next authored beat.
func _play_story_title(title: StringName) -> void:
	while dialogue_router.is_busy():
		await dialogue_router.dialogue_finished
	var started := dialogue_router.play_story(title)
	assert(started, "PhaseFinaleController failed to start authored story title '%s'" % title)
	if started:
		await dialogue_router.story_finished


# Persists only the replay-from-start checkpoint required by Continue.
func _store_finale_start() -> void:
	if LevelModule.instance == null:
		return
	LevelModule.instance.enter_chapter(String(CHAPTER.chapter_id))
	LevelModule.instance.set_phase_checkpoint("chapter_05", "finale", "finale_start")
	SaveSystem.save_slot()


# Marks the fifth chapter complete and reveals the authored final acknowledgement.
func _complete_finale() -> void:
	if LevelModule.instance != null:
		LevelModule.instance.complete_chapter("chapter_05")
		SaveSystem.save_slot()
	end_card.show()
	return_button.grab_focus()


# Returns to the title after the player has seen the last arriving signal.
func _return_to_menu() -> void:
	get_tree().paused = false
	SceneManager.change_scene_to_file(MENU_PATH)


# Keeps the authored low-volume finale streams looping until the scene ends.
func _restart_stream(player: AudioStreamPlayer) -> void:
	player.play()
