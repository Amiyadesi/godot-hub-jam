@tool
class_name SettingScreen
extends SceneManagerBackdrop

signal thanks_requested

const WINDOW_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
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
const GENERAL_HINTS := {
	"display_mode": "选择全屏或固定窗口分辨率。窗口模式会立即关闭无边框显示。",
	"vsync_enabled": "开启垂直同步可减少画面撕裂。",
	"master_volume": "统一控制整体音量。先调这里，再微调其它声部。",
	"music_volume": "调整背景音乐音量。",
	"sfx_volume": "调整动作、界面反馈和机关音效音量。",
	"ui_volume": "调整按钮确认、取消和菜单反馈音效音量。",
	"ambient_volume": "调整环境声和氛围声响。",
	"screen_shake": "调整爆炸等强反馈时的屏幕震动强度。设为 0 则禁用震动。",
	"low_flash_mode": "降低快速闪断和大面积爆闪，保留稳定轮廓、重影与慢脉冲。",
}
var is_in_menu_flag: bool

@onready var return_button: Button = %ReturnButton
@onready var general_tab: Button = %AudioTab
@onready var controls_tab: Button = %ControlsTab
@onready var general_page: ScrollContainer = %AudioPage
@onready var controls_page: ScrollContainer = %ControlsPage
@onready var hint_label: Label = %HintLabel
@onready var reset_general_button: Button = %ResetAudioButton
@onready var thanks_button: Button = %ThanksButton
@onready var display_mode_row: VBoxContainer = %DisplayModeRow
@onready var display_mode_option: OptionButton = %DisplayModeOption
@onready var vsync_row: VBoxContainer = %VSyncRow
@onready var vsync_toggle: CheckButton = %VSyncToggle
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
@onready var low_flash_toggle: CheckButton = %LowFlashToggle
@onready var keybinding_ui: EchoKeybindingUI = %KeybindingUI

var _setting_rows: Array[Dictionary] = []
var _current_tab := 0
var _ignore_ui_changes: bool


# Wires the authored controls to the global settings module.
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_configure_display_options()
	_register_general_rows()
	_connect_signals()
	_configure_button_audio()
	_sync_menu_only_controls()
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
	low_flash_toggle.button_pressed = bool(SettingsModule.instance.get_value("low_flash_mode", false))
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
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	low_flash_toggle.toggled.connect(_on_low_flash_toggled)
	display_mode_row.mouse_entered.connect(_set_hint.bind(GENERAL_HINTS["display_mode"]))
	vsync_row.mouse_entered.connect(_set_hint.bind(GENERAL_HINTS["vsync_enabled"]))
	low_flash_row.mouse_entered.connect(_set_hint.bind(GENERAL_HINTS["low_flash_mode"]))
	low_flash_toggle.focus_entered.connect(_set_hint.bind(GENERAL_HINTS["low_flash_mode"]))
	visibility_changed.connect(_on_visibility_changed)
	close_modal_requested.connect(_on_return_pressed)
	for item in _setting_rows:
		var key := String(item["key"])
		var row := item["row"] as Control
		var slider := item["slider"] as HSlider
		row.mouse_entered.connect(_set_hint.bind(GENERAL_HINTS[key]))
		slider.focus_entered.connect(_set_hint.bind(GENERAL_HINTS[key]))
		slider.value_changed.connect(_on_general_slider_changed.bind(key, item["value"]))


# Adds the fixed display choices exposed by the general settings page.
func _configure_display_options() -> void:
	display_mode_option.clear()
	display_mode_option.add_item("全屏")
	for resolution in WINDOW_RESOLUTIONS:
		display_mode_option.add_item("%d x %d" % [resolution.x, resolution.y])


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


# Switches between general settings and keybinding pages.
func _set_tab(index: int) -> void:
	_current_tab = clampi(index, 0, 1)
	general_page.visible = _current_tab == 0
	controls_page.visible = _current_tab == 1
	general_tab.button_pressed = _current_tab == 0
	controls_tab.button_pressed = _current_tab == 1
	if _current_tab == 0:
		_set_hint("调整显示、声音与辅助设置。改动会立即应用并自动保存。")
		if visible:
			display_mode_option.grab_focus()
	else:
		_set_hint("每个动作可保留多个键盘或手柄绑定。点击绑定可替换，+ 可添加。")
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


# Writes an explicit window size and disables borderless presentation.
func _apply_window_resolution(resolution: Vector2i) -> void:
	SettingsModule.instance.set_value("display_mode", "windowed")
	SettingsModule.instance.set_value("borderless_enabled", false)
	SettingsModule.instance.set_value("window_width", resolution.x)
	SettingsModule.instance.set_value("window_height", resolution.y)


# Persists the VSync switch as soon as it changes.
func _on_vsync_toggled(enabled: bool) -> void:
	if _ignore_ui_changes:
		return
	SettingsModule.instance.set_value("vsync_enabled", enabled)


# Persists the accessibility flash reduction switch immediately.
func _on_low_flash_toggled(enabled: bool) -> void:
	if _ignore_ui_changes:
		return
	SettingsModule.instance.set_value("low_flash_mode", enabled)


# Restores only general display, sound, and accessibility fields.
func _on_reset_general_pressed() -> void:
	for key in GENERAL_KEYS:
		SettingsModule.instance.set_value(key, GENERAL_DEFAULTS[key])
	GameAudio.refresh_runtime_volumes()
	refresh_from_settings()
	_set_hint("通用设置已恢复默认。")


# Closes the modal after flushing the global settings save.
func _on_return_pressed() -> void:
	_save_global_settings()
	get_tree().paused = false
	close_modal()


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


# Updates the two-line explanation panel under the page content.
func _set_hint(text: String) -> void:
	hint_label.text = text


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
	GameAudio.setup_plain_button(vsync_toggle)
	GameAudio.setup_plain_button(low_flash_toggle)


# Shows the credits shortcut only when this modal is opened from the menu.
func _sync_menu_only_controls() -> void:
	thanks_button.visible = is_in_menu_flag
	thanks_button.disabled = not is_in_menu_flag
