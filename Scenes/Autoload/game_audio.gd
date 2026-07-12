extends Node
## Template-wide audio router for music, UI sounds, and runtime bus volume.

const DEFAULT_BUS_LAYOUT: AudioBusLayout = preload("res://default_bus_layout.tres")
const UI_CANCEL_SOUND: AudioStream = preload("res://assets/sfx/ui/cancel/Fantasy_UI (27).wav")
const UI_CONFIRM_INGAME_SOUND: AudioStream = preload("res://assets/sfx/ui/confirm_ingame/Fantasy_UI (4).wav")
const UI_CONFIRM_MENU_SOUND: AudioStream = preload("res://assets/sfx/ui/confirm_menu/Fantasy_UI (5).wav")
const UI_CONFIRM_MENU_VOLUME_DB := -12.0
const UI_CONFIRM_INGAME_VOLUME_DB := -13.0
const UI_CANCEL_VOLUME_DB := -12.0
const SILENCE_DB := -80.0

@export var startup_music: AudioStream
@export var startup_music_key := "menu"

var _current_music_key := ""
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player_index := -1
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_layout(DEFAULT_BUS_LAYOUT)
	_ensure_music_players()
	_apply_sound_manager_buses()
	_connect_settings_signal()
	refresh_runtime_volumes()
	if startup_music != null:
		call_deferred("play_music", startup_music_key, startup_music, 0.1)


func play_music(track_key: String, stream: AudioStream, crossfade_duration := 0.6) -> void:
	if stream == null:
		return
	_ensure_music_players()
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


func play_ui_confirm_menu() -> void:
	_play_ui_sound(UI_CONFIRM_MENU_SOUND, UI_CONFIRM_MENU_VOLUME_DB)


func play_ui_confirm_ingame() -> void:
	_play_ui_sound(UI_CONFIRM_INGAME_SOUND, UI_CONFIRM_INGAME_VOLUME_DB)


func play_ui_cancel() -> void:
	_play_ui_sound(UI_CANCEL_SOUND, UI_CANCEL_VOLUME_DB)


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


func setup_menu_shader_button(button: Node) -> void:
	_set_shader_button_audio(button, UI_CONFIRM_MENU_SOUND, UI_CONFIRM_MENU_VOLUME_DB, "menu_confirm")


func setup_ingame_shader_button(button: Node) -> void:
	_set_shader_button_audio(button, UI_CONFIRM_INGAME_SOUND, UI_CONFIRM_INGAME_VOLUME_DB, "ingame_confirm")


func setup_plain_button(button: Node, sound_kind := "ingame_confirm") -> void:
	button.set_meta("ui_sound_kind", sound_kind)


func refresh_runtime_volumes() -> void:
	_apply_sound_manager_buses()
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


func _ensure_music_players() -> void:
	while _music_players.size() < 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % _music_players.size()
		player.bus = "Music"
		player.volume_db = SILENCE_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_music_players.append(player)


func _get_active_music_player() -> AudioStreamPlayer:
	if _active_music_player_index < 0 or _active_music_player_index >= _music_players.size():
		return null
	return _music_players[_active_music_player_index]


func _play_ui_sound(stream: AudioStream, volume_db := 0.0) -> void:
	var player := SoundManager.play_ui_sound(stream, "UI") as AudioStreamPlayer
	player.volume_db = volume_db


func _set_shader_button_audio(button: Node, press_stream: AudioStream, press_volume_db: float, sound_kind: String) -> void:
	button.set_meta("ui_sound_kind", sound_kind)
	var press_audio := button.get_node("PressAudio") as AudioStreamPlayer
	press_audio.bus = "UI"
	press_audio.stream = press_stream
	press_audio.volume_db = press_volume_db


func _apply_sound_manager_buses() -> void:
	SoundManager.set_default_sound_bus("SFX")
	SoundManager.set_default_ui_sound_bus("UI")
	SoundManager.set_default_ambient_sound_bus("Ambient")
	SoundManager.set_default_music_bus("Music")


func _connect_settings_signal() -> void:
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(_key: String, _value: Variant) -> void:
	refresh_runtime_volumes()


func _get_setting(key: String, fallback: float) -> float:
	return float(SettingsModule.instance.get_value(key, fallback)) if SettingsModule.instance != null else fallback


func _set_bus_volume_linear(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped_volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, SILENCE_DB if clamped_volume <= 0.001 else linear_to_db(clamped_volume))
