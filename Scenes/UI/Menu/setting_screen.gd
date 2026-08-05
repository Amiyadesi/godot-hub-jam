@tool
class_name SettingScreen
extends SceneManagerBackdrop

signal thanks_requested
signal return_completed

const WINDOW_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const LANGUAGE_CODES: Array[String] = ["zh_CN", "en"]
const GENERAL_KEYS := [
	"display_mode", "borderless_enabled", "window_width", "window_height", "vsync_enabled",
	"master_volume", "music_volume", "sfx_volume", "ui_volume", "ambient_volume", "screen_shake",
	"low_flash_mode",
]
const GENERAL_DEFAULTS := {
	"display_mode": "fullscreen",
	"borderless_enabled": false,
	"window_width": 1920,
	"window_height": 1080,
	"vsync_enabled": true,
	"master_volume": 0.8,
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"ui_volume": 0.8,
	"ambient_volume": 0.8,
	"screen_shake": 0.5,
	"low_flash_mode": false,
}
var is_in_menu_flag: bool

@onready var return_button: Button = %ReturnButton
@onready var general_tab: Button = %AudioTab
@onready var controls_tab: Button = %ControlsTab
@onready var general_page: ScrollContainer = %AudioPage
@onready var controls_page: ScrollContainer = %ControlsPage
@onready var reset_general_button: Button = %ResetAudioButton
@onready var thanks_button: Button = %ThanksButton
@onready var display_mode_row: VBoxContainer = %DisplayModeRow
@onready var display_mode_option: OptionButton = %DisplayModeOption
@onready var language_option: OptionButton = %LanguageOption
@onready var vsync_row: VBoxContainer = %VSyncRow
@onready var vsync_toggle: Button = %VSyncToggle
@onready var master_row: VBoxContainer = %MasterRow
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_row: VBoxContainer = %MusicRow
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_row: VBoxContainer = %SfxRow
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var ui_row: VBoxContainer = %UIRow
@onready var ui_slider: HSlider = %UISlider
@onready var ui_value: Label = %UIValue
@onready var ambient_row: VBoxContainer = %AmbientRow
@onready var ambient_slider: HSlider = %AmbientSlider
@onready var ambient_value: Label = %AmbientValue
@onready var screen_shake_row: VBoxContainer = %ScreenShakeRow
@onready var screen_shake_slider: HSlider = %ScreenShakeSlider
@onready var screen_shake_value: Label = %ScreenShakeValue
@onready var low_flash_row: VBoxContainer = %LowFlashRow
@onready var low_flash_toggle: Button = %LowFlashToggle
@onready var keybinding_ui: EchoKeybindingUI = %KeybindingUI

var _setting_rows: Array[Dictionary] = []
var _current_tab := 0
var _ignore_ui_changes: bool
var _return_in_progress := false


# Wires the authored controls to the global settings module.
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_configure_display_options()
	_configure_language_options()
	_register_general_rows()
	_connect_signals()
	_configure_button_audio()
	_sync_menu_only_controls()
	if OS.has_feature("mobile"):
		controls_tab.hide()
		controls_page.hide()
	refresh_from_settings()
	_set_tab(0)


# Refreshes every visible control from the persisted global settings.
func refresh_from_settings() -> void:
	_ignore_ui_changes = true
	for item in _setting_rows:
		var key := String(item["key"])
		var slider := item["slider"] as HSlider
		var value_label := item["value"] as Label
		slider.value = _get_setting_value(key)
		_update_value_label(value_label, slider.value)
	_sync_display_controls()
	_sync_language_option()
	low_flash_toggle.button_pressed = bool(SettingsModule.instance.get_value("low_flash_mode", false))
	_sync_toggle_labels()
	_ignore_ui_changes = false
	keybinding_ui.refresh_all()


# Exposes the selected authored page for modal return routing.
func get_current_tab() -> int:
	return _current_tab


# Selects one authored page while preserving the existing focus rules.
func select_tab(index: int) -> void:
	_set_tab(index)


# Connects the authored controls once for live settings changes.
func _connect_signals() -> void:
	return_button.pressed.connect(_on_return_pressed)
	thanks_button.pressed.connect(_on_thanks_pressed)
	reset_general_button.pressed.connect(_on_reset_general_pressed)
	general_tab.pressed.connect(_set_tab.bind(0))
	controls_tab.pressed.connect(_set_tab.bind(1))
	general_tab.mouse_entered.connect(general_tab.grab_focus)
	controls_tab.mouse_entered.connect(controls_tab.grab_focus)
	display_mode_option.item_selected.connect(_on_display_mode_selected)
	language_option.item_selected.connect(_on_language_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	low_flash_toggle.toggled.connect(_on_low_flash_toggled)
	visibility_changed.connect(_on_visibility_changed)
	close_modal_requested.connect(_on_return_pressed)
	SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	for item in _setting_rows:
		var key := String(item["key"])
		var slider := item["slider"] as HSlider
		slider.value_changed.connect(_on_general_slider_changed.bind(key, item["value"]))


# Adds the fixed display choices exposed by the general settings page.
func _configure_display_options() -> void:
	display_mode_option.clear()
	display_mode_option.add_item(tr("SETTINGS_FULLSCREEN"))
	for resolution in WINDOW_RESOLUTIONS:
		display_mode_option.add_item("%d x %d" % [resolution.x, resolution.y])


# 重建两项语言选择，使 OptionButton 在切换后立即显示当前语言文字。
func _configure_language_options() -> void:
	language_option.clear()
	language_option.add_item(tr("SETTINGS_LANGUAGE_ZH"))
	language_option.add_item(tr("SETTINGS_LANGUAGE_EN"))


# 让语言选择始终反映已规范化的全局 locale。
func _sync_language_option() -> void:
	var language_code := str(SettingsModule.instance.get_value("language", "zh_CN"))
	language_option.select(LANGUAGE_CODES.find(language_code))


# Registers authored slider rows with their matching saved fields.
func _register_general_rows() -> void:
	_setting_rows = [
		{"key": "master_volume", "row": master_row, "slider": master_slider, "value": master_value},
		{"key": "music_volume", "row": music_row, "slider": music_slider, "value": music_value},
		{"key": "sfx_volume", "row": sfx_row, "slider": sfx_slider, "value": sfx_value},
		{"key": "ui_volume", "row": ui_row, "slider": ui_slider, "value": ui_value},
		{"key": "ambient_volume", "row": ambient_row, "slider": ambient_slider, "value": ambient_value},
		{"key": "screen_shake", "row": screen_shake_row, "slider": screen_shake_slider, "value": screen_shake_value},
	]


# Synchronizes display selectors after loading or restoring settings.
func _sync_display_controls() -> void:
	var display_mode := str(SettingsModule.instance.get_value("display_mode", "fullscreen"))
	if display_mode == "fullscreen":
		display_mode_option.select(0)
	else:
		var saved_resolution := Vector2i(
			int(SettingsModule.instance.get_value("window_width", 1920)),
			int(SettingsModule.instance.get_value("window_height", 1080))
		)
		display_mode_option.select(WINDOW_RESOLUTIONS.size())
		for index in WINDOW_RESOLUTIONS.size():
			if WINDOW_RESOLUTIONS[index] == saved_resolution:
				display_mode_option.select(index + 1)
				break
	vsync_toggle.button_pressed = bool(SettingsModule.instance.get_value("vsync_enabled", true))
	_sync_toggle_labels()


# 将二元设置显示为简洁的文本状态。
func _sync_toggle_labels() -> void:
	vsync_toggle.text = "[ %s ]" % tr("SETTINGS_ON" if vsync_toggle.button_pressed else "SETTINGS_OFF")
	low_flash_toggle.text = "[ %s ]" % tr("SETTINGS_ON" if low_flash_toggle.button_pressed else "SETTINGS_OFF")


# Switches between general settings and keybinding pages.
func _set_tab(index: int) -> void:
	if OS.has_feature("mobile"):
		index = 0
	_current_tab = clampi(index, 0, 1)
	general_page.visible = _current_tab == 0
	controls_page.visible = _current_tab == 1
	general_tab.button_pressed = _current_tab == 0
	controls_tab.button_pressed = _current_tab == 1
	if _current_tab == 0:
		if visible:
			display_mode_option.grab_focus()
	else:
		if visible:
			keybinding_ui.focus_first_row()


# Stores one slider value and immediately updates runtime audio services.
func _on_general_slider_changed(value: float, key: String, value_label: Label) -> void:
	_update_value_label(value_label, value)
	if _ignore_ui_changes:
		return
	SettingsModule.instance.set_value(key, value)
	GameAudio.refresh_runtime_volumes()


# Applies the selected fullscreen or fixed window preset.
func _on_display_mode_selected(index: int) -> void:
	if _ignore_ui_changes:
		return
	if index == 0:
		SettingsModule.instance.set_value("display_mode", "fullscreen")
		SettingsModule.instance.set_value("borderless_enabled", false)
		return
	var resolution: Vector2i = WINDOW_RESOLUTIONS[index - 1]
	_apply_window_resolution(resolution)


# 保存语言后由 SettingsModule 切换 TranslationServer，并刷新动态文本。
func _on_language_selected(index: int) -> void:
	if _ignore_ui_changes:
		return
	SettingsModule.instance.set_value("language", LANGUAGE_CODES[index])


# 语言改变时重建不会自动翻译的选项和按键显示。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "language":
		return
	_ignore_ui_changes = true
	_configure_display_options()
	_configure_language_options()
	_sync_display_controls()
	_sync_language_option()
	_ignore_ui_changes = false
	keybinding_ui.refresh_all()


# Writes an explicit window size and disables borderless presentation.
func _apply_window_resolution(resolution: Vector2i) -> void:
	SettingsModule.instance.set_value("display_mode", "windowed")
	SettingsModule.instance.set_value("borderless_enabled", false)
	SettingsModule.instance.set_value("window_width", resolution.x)
	SettingsModule.instance.set_value("window_height", resolution.y)


# Persists the VSync switch as soon as it changes.
func _on_vsync_toggled(enabled: bool) -> void:
	_sync_toggle_labels()
	if _ignore_ui_changes:
		return
	SettingsModule.instance.set_value("vsync_enabled", enabled)


# Persists the accessibility flash reduction switch immediately.
func _on_low_flash_toggled(enabled: bool) -> void:
	_sync_toggle_labels()
	if _ignore_ui_changes:
		return
	SettingsModule.instance.set_value("low_flash_mode", enabled)


# Restores only general display, sound, and accessibility fields.
func _on_reset_general_pressed() -> void:
	for key in GENERAL_KEYS:
		SettingsModule.instance.set_value(key, GENERAL_DEFAULTS[key])
	GameAudio.refresh_runtime_volumes()
	refresh_from_settings()


# 让按钮和 Esc 共用同一条保存与返回路径。
func _on_return_pressed() -> void:
	request_return()


# 保存设置并关闭页面；是否解除暂停由调用场景决定。
func request_return() -> void:
	if _return_in_progress or not visible:
		return
	_return_in_progress = true
	_save_global_settings()
	var tween := close_modal()
	if tween != null:
		await tween.finished
	_return_in_progress = false
	return_completed.emit()


# 将 Esc 路由到与返回按钮相同的公开接口。
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	request_return()


# Hands off from settings to the authored credits modal.
func _on_thanks_pressed() -> void:
	_save_global_settings()
	thanks_requested.emit()


# Refreshes settings while opening and persists them while closing.
func _on_visibility_changed() -> void:
	_sync_menu_only_controls()
	if visible:
		refresh_from_settings()
		call_deferred("_restore_focus")
	else:
		_save_global_settings()


# Restores keyboard focus to the active settings page.
func _restore_focus() -> void:
	if not visible:
		return
	if _current_tab == 0:
		display_mode_option.grab_focus()
	else:
		keybinding_ui.focus_first_row()


# Reads a slider field from the registered global settings module.
func _get_setting_value(key: String) -> float:
	return float(SettingsModule.instance.get_value(key, GENERAL_DEFAULTS[key]))


# Formats slider values consistently as whole-number percentages.
func _update_value_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(round(value * 100.0))


# Persists global settings through the registered project save system.
func _save_global_settings() -> void:
	SaveSystem.save_global()


# Connects this page's buttons to the shared UI audio router.
func _configure_button_audio() -> void:
	GameAudio.setup_ingame_shader_button(return_button)
	GameAudio.setup_ingame_shader_button(thanks_button)
	GameAudio.setup_ingame_shader_button(reset_general_button)
	GameAudio.setup_plain_button(return_button, "cancel")
	GameAudio.setup_plain_button(general_tab)
	GameAudio.setup_plain_button(controls_tab)
	GameAudio.setup_plain_button(display_mode_option)
	GameAudio.setup_plain_button(language_option)
	GameAudio.setup_plain_button(vsync_toggle)
	GameAudio.setup_plain_button(low_flash_toggle)


# Shows the credits shortcut only when this modal is opened from the menu.
func _sync_menu_only_controls() -> void:
	thanks_button.visible = is_in_menu_flag
	thanks_button.disabled = not is_in_menu_flag
