class_name PhaseAudioDirector
extends Node
## Selects authored chapter music and keeps facility ambience under layout control.

@export_range(-40.0, 0.0, 0.5, "suffix:dB") var music_volume_db: float = -10.0
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var ambient_volume_db: float = -14.0
@export var puzzle_music: AudioStream
@export var cold_music: AudioStream
@export var battle_music: AudioStream

@onready var main_music: AudioStreamPlayer = $MainMusic
@onready var factory_ambient: AudioStreamPlayer = $FactoryAmbient


# Starts the authored facility bed; chapter flow selects the score after setup.
func _ready() -> void:
	for player: AudioStreamPlayer in [main_music, factory_ambient]:
		player.finished.connect(_restart_loop.bind(player))
	main_music.volume_db = music_volume_db
	factory_ambient.play()
	set_space_weights(0.72, 0.72, 0.0)


# Selects the authored score for one chapter without restarting an unchanged track.
func set_chapter(chapter_index: int) -> void:
	var chapter_music: AudioStream
	match chapter_index:
		0, 1, 4:
			chapter_music = puzzle_music
		2:
			chapter_music = cold_music
		3:
			chapter_music = battle_music
		_:
			push_error("PhaseAudioDirector.set_chapter: unsupported chapter index %d" % chapter_index)
			return
	_play_music(chapter_music)


# Switches explicit combat beats to the authored battle score.
func play_battle() -> void:
	_play_music(battle_music)


# Crossfades facility ambience with the current split-layout emphasis.
func set_space_weights(lu_weight: float, xing_weight: float, duration: float = 0.36) -> void:
	var ambient_db := _weight_to_db(maxf(lu_weight, xing_weight))
	if duration <= 0.0:
		factory_ambient.volume_db = ambient_db
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(factory_ambient, ^"volume_db", ambient_db, duration)


# Starts one score only when its authored stream differs from the active track.
func _play_music(stream: AudioStream) -> void:
	if stream == null:
		push_error("PhaseAudioDirector._play_music requires an authored stream")
		return
	if main_music.stream == stream and main_music.playing:
		return
	main_music.stream = stream
	main_music.volume_db = music_volume_db
	main_music.play()


# Restarts one authored music or ambience stream at its natural end.
func _restart_loop(player: AudioStreamPlayer) -> void:
	player.play()


# Maps layout weight into the Ambient bus while retaining an authored base level.
func _weight_to_db(weight: float) -> float:
	if weight <= 0.001:
		return -80.0
	return ambient_volume_db + linear_to_db(clampf(weight, 0.001, 1.0))
