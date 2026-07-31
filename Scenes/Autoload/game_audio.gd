extends Node
## Template-wide audio router for music, UI sounds, and runtime bus volume.

const DEFAULT_BUS_LAYOUT: AudioBusLayout = preload("res://default_bus_layout.tres")
const SILENCE_DB := -80.0

@export var startup_music: AudioStream
@export var startup_music_key := "menu"

@onready var music_player_0: AudioStreamPlayer = %MusicPlayer0
@onready var music_player_1: AudioStreamPlayer = %MusicPlayer1
@onready var ui_confirm_menu: AudioStreamPlayer = %UiConfirmMenu
@onready var ui_confirm_ingame: AudioStreamPlayer = %UiConfirmIngame
@onready var ui_cancel: AudioStreamPlayer = %UiCancel

var _current_music_key := ""
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player_index := -1
var _music_tween: Tween


# Initializes the authored players and applies persisted bus volumes.
func _ready() -> void:
	AudioServer.set_bus_layout(DEFAULT_BUS_LAYOUT)
	_music_players = [music_player_0, music_player_1]
	for player in _music_players:
		player.finished.connect(_on_music_player_finished.bind(player))
	_connect_settings_signal()
	refresh_runtime_volumes()
	if startup_music != null:
		call_deferred("play_music", startup_music_key, startup_music, 0.1)


# Crossfades to one keyed score without restarting the active stream.
func play_music(track_key: String, stream: AudioStream, crossfade_duration := 0.6) -> void:
	if stream == null:
		return
	var active_player := _get_active_music_player()
	if _current_music_key == track_key and active_player != null and active_player.playing and active_player.stream == stream:
		return

	_current_music_key = track_key
	var next_index := 0 if _active_music_player_index != 0 else 1
	var next_player := _music_players[next_index]
	var previous_player := active_player
	_active_music_player_index = next_index

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	next_player.bus = "Music"
	next_player.stream = stream
	next_player.stream_paused = false
	next_player.volume_db = SILENCE_DB if crossfade_duration > 0.0 else 0.0
	next_player.play()

	if crossfade_duration <= 0.0:
		if previous_player != null and previous_player != next_player:
			previous_player.stop()
			previous_player.stream = null
		next_player.volume_db = 0.0
		return

	_music_tween = create_tween()
	_music_tween.set_ignore_time_scale(true)
	_music_tween.parallel().tween_property(next_player, "volume_db", 0.0, crossfade_duration)
	if previous_player != null and previous_player != next_player and previous_player.playing:
		_music_tween.parallel().tween_property(previous_player, "volume_db", SILENCE_DB, crossfade_duration)
		_music_tween.finished.connect(func() -> void:
			if is_instance_valid(previous_player) and previous_player != _get_active_music_player():
				previous_player.stop()
				previous_player.stream = null
		, CONNECT_ONE_SHOT)


# Fades out every music player and clears the current track identity.
func stop_music(fade_out_duration := 0.3) -> void:
	_current_music_key = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if fade_out_duration <= 0.0:
		for player in _music_players:
			player.stop()
			player.stream = null
			player.volume_db = SILENCE_DB
		_active_music_player_index = -1
		return
	_music_tween = create_tween()
	_music_tween.set_ignore_time_scale(true)
	for player in _music_players:
		if player.playing:
			_music_tween.parallel().tween_property(player, "volume_db", SILENCE_DB, fade_out_duration)
	_music_tween.finished.connect(func() -> void:
		for player in _music_players:
			player.stop()
			player.stream = null
			player.volume_db = SILENCE_DB
		_active_music_player_index = -1
	, CONNECT_ONE_SHOT)


# Plays the authored menu confirmation sound.
func play_ui_confirm_menu() -> void:
	ui_confirm_menu.play()


# Plays the authored in-game confirmation sound.
func play_ui_confirm_ingame() -> void:
	ui_confirm_ingame.play()


# Plays the authored cancellation sound.
func play_ui_cancel() -> void:
	ui_cancel.play()


# Routes one button press through its authored sound category.
func play_ui_button_press(button: Node) -> void:
	match str(button.get_meta("ui_sound_kind", "ingame_confirm")):
		"menu_confirm":
			play_ui_confirm_menu()
		"cancel":
			play_ui_cancel()
		"none":
			pass
		_:
			play_ui_confirm_ingame()


# Assigns menu confirmation audio to one authored shader button.
func setup_menu_shader_button(button: Node) -> void:
	button.set_meta("ui_sound_kind", "menu_confirm")


# Assigns in-game confirmation audio to one authored shader button.
func setup_ingame_shader_button(button: Node) -> void:
	button.set_meta("ui_sound_kind", "ingame_confirm")


# Stores a sound category on a plain authored button.
func setup_plain_button(button: Node, sound_kind := "ingame_confirm") -> void:
	button.set_meta("ui_sound_kind", sound_kind)


# Applies persisted master and category volumes to live audio buses.
func refresh_runtime_volumes() -> void:
	var master_volume := _get_setting("master_volume", 0.8)
	var music_volume := _get_setting("music_volume", 0.8)
	var sfx_volume := _get_setting("sfx_volume", 0.8)
	var ui_volume := _get_setting("ui_volume", 0.8)
	var ambient_volume := _get_setting("ambient_volume", 0.8)
	_set_bus_volume_linear("Master", master_volume)
	_set_bus_volume_linear("Music", music_volume)
	_set_bus_volume_linear("SFX", sfx_volume)
	_set_bus_volume_linear("UI", ui_volume)
	_set_bus_volume_linear("Ambient", ambient_volume)


# Returns the player currently owning the active keyed score.
func _get_active_music_player() -> AudioStreamPlayer:
	if _active_music_player_index < 0 or _active_music_player_index >= _music_players.size():
		return null
	return _music_players[_active_music_player_index]


# Restarts only the current active score when a source reaches its natural end.
func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if player != _get_active_music_player() or player.stream == null or _current_music_key.is_empty():
		return
	player.play()


# Refreshes runtime buses whenever persisted settings change.
func _connect_settings_signal() -> void:
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_settings_changed)


# Reapplies all bus levels after one settings value changes.
func _on_settings_changed(_key: String, _value: Variant) -> void:
	refresh_runtime_volumes()


# Reads one numeric setting while supporting startup before the module exists.
func _get_setting(key: String, fallback: float) -> float:
	return float(SettingsModule.instance.get_value(key, fallback)) if SettingsModule.instance != null else fallback


# Converts a normalized value into the target Godot bus level.
func _set_bus_volume_linear(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped_volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, SILENCE_DB if clamped_volume <= 0.001 else linear_to_db(clamped_volume))
