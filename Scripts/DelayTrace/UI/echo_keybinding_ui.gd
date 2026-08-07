class_name EchoKeybindingUI
extends VBoxContainer
## 由全局输入存档模块驱动的固定 authored 键位行。

const ACTION_LABELS := {
	&"echo_move_left": "INPUT_MOVE_LEFT",
	&"echo_move_right": "INPUT_MOVE_RIGHT",
	&"echo_move_up": "INPUT_MOVE_UP",
	&"echo_move_down": "INPUT_MOVE_DOWN",
	&"echo_dash": "INPUT_DASH",
	&"echo_jump": "INPUT_JUMP",
	&"echo_recall": "INPUT_RECALL",
	&"pause": "INPUT_PAUSE",
}

@onready var move_left_button: Button = %MoveLeftButton
@onready var move_right_button: Button = %MoveRightButton
@onready var move_up_button: Button = %MoveUpButton
@onready var move_down_button: Button = %MoveDownButton
@onready var dash_button: Button = %DashButton
@onready var jump_button: Button = %JumpButton
@onready var recall_button: Button = %RecallButton
@onready var pause_button: Button = %PauseButton
@onready var capture_dialog: KeyCaptureDialog = %KeyCaptureDialog

var _capture_button: Button
var _capture_action: StringName


# 将每个固定 authored 动作行连接到共享捕获对话框。
func _ready() -> void:
	if OS.has_feature("mobile"):
		hide()
		return
	_connect_binding_button(move_left_button, &"echo_move_left")
	_connect_binding_button(move_right_button, &"echo_move_right")
	_connect_binding_button(move_up_button, &"echo_move_up")
	_connect_binding_button(move_down_button, &"echo_move_down")
	_connect_binding_button(dash_button, &"echo_dash")
	_connect_binding_button(jump_button, &"echo_jump")
	_connect_binding_button(recall_button, &"echo_recall")
	_connect_binding_button(pause_button, &"pause")
	capture_dialog.key_captured.connect(_on_key_captured)
	capture_dialog.capture_cancelled.connect(_on_capture_cancelled)
	if KeybindingModule.instance != null:
		KeybindingModule.instance.bindings_changed.connect(refresh_all)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	refresh_all()


# 载入或替换绑定后刷新全部显示文本。
func refresh_all() -> void:
	_refresh_button(move_left_button, &"echo_move_left")
	_refresh_button(move_right_button, &"echo_move_right")
	_refresh_button(move_up_button, &"echo_move_up")
	_refresh_button(move_down_button, &"echo_move_down")
	_refresh_button(dash_button, &"echo_dash")
	_refresh_button(jump_button, &"echo_jump")
	_refresh_button(recall_button, &"echo_recall")
	_refresh_button(pause_button, &"pause")


# 控制页打开时聚焦第一条 authored 键位行。
func focus_first_row() -> void:
	move_left_button.grab_focus()


# 将一个 authored 按钮连接到稳定 InputMap action。
func _connect_binding_button(button: Button, action: StringName) -> void:
	button.pressed.connect(_open_capture.bind(action, button))


# 为一个动作打开捕获，并记录关闭后焦点返回位置。
func _open_capture(action: StringName, button: Button) -> void:
	_capture_action = action
	_capture_button = button
	capture_dialog.open_for(String(action), tr(ACTION_LABELS[action]), false)


# 捕获成功后替换主事件并持久化。
func _on_key_captured(event: InputEvent, action: String) -> void:
	if KeybindingModule.instance == null:
		push_error("EchoKeybindingUI requires KeybindingModule")
		return
	KeybindingModule.instance.rebind_action_primary(action, event)
	SaveSystem.save_global()
	refresh_all()
	_restore_capture_focus()


# 捕获取消后恢复发起操作的键位行。
func _on_capture_cancelled(_action: String) -> void:
	_restore_capture_focus()


# 为固定 authored 行格式化当前主绑定。
func _refresh_button(button: Button, action: StringName) -> void:
	var binding_text := tr("INPUT_UNBOUND")
	if KeybindingModule.instance != null:
		var events := KeybindingModule.instance.get_action_events(String(action))
		if not events.is_empty():
			binding_text = ResourceSerializer.event_to_display_string(events[0])
	button.text = binding_text


# 语言切换后刷新动态按键名和捕获弹窗的动作文字。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "language":
		refresh_all()


# 捕获关闭后将 GUI 焦点还给原动作行。
func _restore_capture_focus() -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.grab_focus()
	_capture_button = null
	_capture_action = &""
