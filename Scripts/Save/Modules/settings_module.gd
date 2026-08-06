class_name SettingsModule
extends ISaveModule
## 全局存档模块 — 游戏设置
##
## 负责存储所有与设备/账号绑定的设置，
## 属于全局存档（is_global = true），不随槽位切换而改变。
##
## 用法：
##   SaveSystem.register_module(SettingsModule.new())
##
## 读取设置：
##   var vol = SettingsModule.instance.get_value("master_volume", 0.8)
##
## 修改设置：
##   SettingsModule.instance.set_value("master_volume", 0.5)
##   SaveSystem.save_global()   # 立即落盘

signal settings_changed(key: String, value: Variant)

## 单例引用（注册后自动赋值）
static var instance: SettingsModule

# ──────────────────────────────────────────────
# 默认值（新游戏 / 重置用）
# ──────────────────────────────────────────────
const DEFAULTS := {
	"master_volume"  : 0.8,
	"music_volume"   : 0.8,
	"sfx_volume"     : 0.8,
	"ui_volume"      : 0.8,
	"ambient_volume" : 0.8,
	"screen_shake"   : 0.5,
	"low_flash_mode" : false,
	"show_past_trace": false,
	"show_future_timer": false,
	"language"       : "zh_CN",
	"display_mode"   : "fullscreen",
	"borderless_enabled": false,
	"window_width"   : 1920,
	"window_height"  : 1080,
	"vsync_enabled"  : true,
	"timezone_mode"  : "system",
	"custom_time_hour": 12,
	"custom_time_minute": 0,
}

var _values: Dictionary = {}
var _save_request_serial: int = 0

# Registers the latest settings module instance and hooks global-load application.
func _init() -> void:
	_values = _default_values()
	instance = self
	var save_system := _get_save_system()
	if save_system != null and save_system.has_signal("global_loaded"):
		save_system.global_loaded.connect(_on_global_loaded)

# ──────────────────────────────────────────────
# ISaveModule 接口
# ──────────────────────────────────────────────

# Returns the stable global-save key for device/account settings.
func get_module_key() -> String:
	return "settings"

# Stores settings globally because they are shared by all save slots.
func is_global() -> bool:
	return true

# Captures normalized settings for serialization.
func collect_data() -> Dictionary:
	return _values.duplicate(true)

# Applies persisted settings, migrates legacy keys, and normalizes values.
func apply_data(data: Dictionary) -> void:
	_values = _default_values()
	for key in data:
		_values[key] = data[key]
	_migrate_legacy_settings(data)
	_normalize_values()

# Provides default settings for first-run global saves.
func get_default_data() -> Dictionary:
	return _default_values()

# Resets settings to defaults and applies them to the running game.
func on_new_game() -> void:
	_values = _default_values()
	apply_all()


# Persists current settings during the SaveSystem shutdown hook.
func on_win_closed() -> void:
	var save_system := _get_save_system()
	if save_system != null and save_system.has_method("save_global"):
		save_system.call("save_global")

# ──────────────────────────────────────────────
# 公开 API
# ──────────────────────────────────────────────

# Reads one setting value with default fallback support.
func get_value(key: String, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback if fallback != null else DEFAULTS.get(key))

# Writes, applies, emits, and queues persistence for one changed setting.
func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_normalize_values()
	apply_setting(key, _values[key])
	settings_changed.emit(key, _values[key])
	_queue_save()

# Restores all settings to defaults and queues persistence.
func reset_to_defaults() -> void:
	var previous_values := _values.duplicate(true)
	_values = DEFAULTS.duplicate(true)
	apply_all()
	for key: String in DEFAULTS:
		if previous_values.get(key) != _values[key]:
			settings_changed.emit(key, _values[key])
	_queue_save()

# Returns a defensive copy of all current settings.
func get_all() -> Dictionary:
	return _values.duplicate(true)


# Applies every known setting to the active runtime services.
func apply_all() -> void:
	_normalize_values()
	for key in DEFAULTS.keys():
		apply_setting(key, _values.get(key, DEFAULTS[key]))


# Applies one setting to the runtime system it controls.
func apply_setting(key: String, value: Variant) -> void:
	match key:
		"language":
			_apply_language(str(value))
		"master_volume", "music_volume", "sfx_volume", "ui_volume", "ambient_volume":
			pass
		"display_mode", "borderless_enabled", "window_width", "window_height":
			_apply_display_mode()
		"vsync_enabled":
			_apply_vsync(_is_truthy(value))
		"timezone_mode", "custom_time_hour", "custom_time_minute", "screen_shake", "low_flash_mode", \
		"show_past_trace", "show_future_timer":
			pass


# Reapplies settings once the global save has loaded.
func _on_global_loaded(_ok: bool) -> void:
	apply_all()


# Converts legacy setting keys and values into the current schema.
func _migrate_legacy_settings(data: Dictionary) -> void:
	if data.has("fullscreen") and not data.has("display_mode"):
		_values["display_mode"] = "fullscreen" if _is_truthy(data.get("fullscreen", false)) else "windowed"
	if str(data.get("display_mode", "")) == "borderless":
		_values["display_mode"] = "windowed"
		_values["borderless_enabled"] = true
	var legacy_mode := str(data.get("timezone_mode", "system"))
	if legacy_mode == "manual":
		var offset_minutes := clampi(int(data.get("timezone_offset_minutes", 0)), -720, 840)
		var custom_time := _build_legacy_custom_time_from_offset(offset_minutes)
		_values["timezone_mode"] = "custom"
		_values["custom_time_hour"] = custom_time["hour"]
		_values["custom_time_minute"] = custom_time["minute"]
	elif not data.has("custom_time_hour") or not data.has("custom_time_minute"):
		var system_time := _get_system_time_seed()
		_values["custom_time_hour"] = int(system_time.get("hour", DEFAULTS["custom_time_hour"]))
		_values["custom_time_minute"] = int(system_time.get("minute", DEFAULTS["custom_time_minute"]))
	_values.erase("fullscreen")
	_values.erase("timezone_offset_minutes")


# Clamps and coerces all settings into the supported runtime ranges.
func _normalize_values() -> void:
	_values["master_volume"] = clampf(float(_values.get("master_volume", DEFAULTS["master_volume"])), 0.0, 1.0)
	_values["music_volume"] = clampf(float(_values.get("music_volume", DEFAULTS["music_volume"])), 0.0, 1.0)
	_values["sfx_volume"] = clampf(float(_values.get("sfx_volume", DEFAULTS["sfx_volume"])), 0.0, 1.0)
	_values["ui_volume"] = clampf(float(_values.get("ui_volume", DEFAULTS["ui_volume"])), 0.0, 1.0)
	_values["ambient_volume"] = clampf(float(_values.get("ambient_volume", DEFAULTS["ambient_volume"])), 0.0, 1.0)
	_values["screen_shake"] = clampf(float(_values.get("screen_shake", DEFAULTS["screen_shake"])), 0.0, 1.0)
	_values["low_flash_mode"] = _is_truthy(_values.get("low_flash_mode", DEFAULTS["low_flash_mode"]))
	_values["show_past_trace"] = _is_truthy(_values.get("show_past_trace", DEFAULTS["show_past_trace"]))
	_values["show_future_timer"] = _is_truthy(_values.get("show_future_timer", DEFAULTS["show_future_timer"]))
	_values["display_mode"] = _normalize_display_mode(str(_values.get("display_mode", DEFAULTS["display_mode"])))
	_values["borderless_enabled"] = _is_truthy(_values.get("borderless_enabled", DEFAULTS["borderless_enabled"]))
	_values["window_width"] = maxi(640, int(_values.get("window_width", DEFAULTS["window_width"])))
	_values["window_height"] = maxi(360, int(_values.get("window_height", DEFAULTS["window_height"])))
	_values["vsync_enabled"] = _is_truthy(_values.get("vsync_enabled", DEFAULTS["vsync_enabled"]))
	_values["timezone_mode"] = "custom" if str(_values.get("timezone_mode", DEFAULTS["timezone_mode"])) == "custom" else "system"
	_values["custom_time_hour"] = clampi(int(_values.get("custom_time_hour", DEFAULTS["custom_time_hour"])), 0, 23)
	_values["custom_time_minute"] = clampi(int(_values.get("custom_time_minute", DEFAULTS["custom_time_minute"])), 0, 59)
	_values["language"] = _normalize_language(str(_values.get("language", _get_system_language())))


# Converts unknown display mode strings back to a supported mode.
func _normalize_display_mode(value: String) -> String:
	match value:
		"windowed", "fullscreen":
			return value
		_:
			return str(DEFAULTS["display_mode"])


# 只保留项目实际提供的两种语言，避免旧存档写入无效 locale。
func _normalize_language(value: String) -> String:
	return value if value in ["en", "zh_CN"] else _get_system_language()


# Builds first-run defaults without overwriting an explicitly saved language.
func _default_values() -> Dictionary:
	var defaults := DEFAULTS.duplicate(true)
	defaults["language"] = _get_system_language()
	return defaults


# Selects Chinese for Chinese system locales and English for all others.
func _get_system_language() -> String:
	return "zh_CN" if OS.get_locale_language().to_lower().begins_with("zh") else "en"


# Applies the active locale to Godot's translation server.
func _apply_language(language_code: String) -> void:
	TranslationServer.set_locale(language_code)
	DisplayServer.window_set_title(TranslationServer.translate(&"GAME_TITLE"))



# Applies fullscreen/windowed/borderless size and position to the root window.
func _apply_display_mode() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return

	var root_window := tree.root
	var display_mode := str(_values.get("display_mode", DEFAULTS["display_mode"]))
	var borderless_enabled := _is_truthy(_values.get("borderless_enabled", DEFAULTS["borderless_enabled"]))
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
	root_window.unresizable = false
	match display_mode:
		"fullscreen":
			root_window.mode = Window.MODE_FULLSCREEN
			root_window.borderless = false
		_:
			root_window.mode = Window.MODE_WINDOWED
			root_window.borderless = borderless_enabled
			var target_size := Vector2i(
				int(_values.get("window_width", DEFAULTS["window_width"])),
				int(_values.get("window_height", DEFAULTS["window_height"]))
			)
			root_window.size = target_size
			if usable_rect.size != Vector2i.ZERO:
				var centered: Vector2i = usable_rect.position + Vector2i((usable_rect.size - target_size) * 0.5)
				root_window.position = centered
			elif screen_size != Vector2i.ZERO:
				root_window.position = screen_position + Vector2i((screen_size - target_size) * 0.5)


# Applies vertical sync mode through DisplayServer.
func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)


# Schedules a debounced global save after setting changes.
func _queue_save() -> void:
	var save_system := _get_save_system()
	if save_system == null:
		return
	var tree := save_system.get_tree()
	if tree == null:
		return
	_save_request_serial += 1
	var serial := _save_request_serial
	tree.create_timer(0.35).timeout.connect(_flush_debounced_save.bind(serial), CONNECT_ONE_SHOT)


# Flushes the newest debounced settings save request.
func _flush_debounced_save(serial: int) -> void:
	if serial != _save_request_serial:
		return
	var save_system := _get_save_system()
	if save_system != null and save_system.has_method("save_global"):
		save_system.call("save_global")


# Finds the SaveSystem autoload when running inside a SceneTree.
func _get_save_system() -> Node:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var root := (main_loop as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null("SaveSystem")


# Reads current system time for legacy timezone migration.
func _get_system_time_seed() -> Dictionary:
	return Time.get_datetime_dict_from_system()


# Converts a legacy manual timezone offset into custom clock seed values.
func _build_legacy_custom_time_from_offset(offset_minutes: int) -> Dictionary:
	var unix_now := int(Time.get_unix_time_from_system()) + offset_minutes * 60
	var datetime := Time.get_datetime_dict_from_unix_time(unix_now)
	return {
		"hour": clampi(int(datetime.get("hour", DEFAULTS["custom_time_hour"])), 0, 23),
		"minute": clampi(int(datetime.get("minute", DEFAULTS["custom_time_minute"])), 0, 59),
	}


# Coerces common scalar values to bool for loaded settings.
func _is_truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return not is_zero_approx(value)
	if value is String:
		var trimmed := String(value).strip_edges().to_lower()
		return trimmed in ["true", "1", "yes", "on"]
	return false
