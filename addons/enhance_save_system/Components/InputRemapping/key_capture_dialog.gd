class_name KeyCaptureDialog
extends AcceptDialog
## 按键捕获弹窗
##
## 弹出后显示提示文字，等待玩家按下允许的键盘、鼠标或手柄输入，
## 捕获到后自动关闭并通过信号回传事件。
##
## 用法（通常由 KeybindingRow / KeybindingUI 内部使用）：
##   通过 key_capture_dialog.tscn 或包含它的父场景实例化。
##   dlg.key_captured.connect(func(ev, action): do_rebind(action, ev))
##   dlg.open_for(action_name, display_name)

## 捕获到输入后触发，携带事件和对应的 action 名称
signal key_captured(event: InputEvent, action: String)
## 用户取消（点击 OK 按钮或按 ESC）
signal capture_cancelled(action: String)

## 当前正在重绑定的 action 名称
var _current_action: String = ""
var _current_display_name: String = ""
var _allow_mouse_buttons: bool = true

## 是否正在等待输入
var _waiting: bool = false

@onready var _label: Label = %PromptLabel


# Wires authored dialog controls and validates the scene contract.
func _ready() -> void:
	if _label == null:
		push_error("KeyCaptureDialog: PromptLabel missing from authored scene")
	confirmed.connect(_on_cancelled)
	canceled.connect(_on_cancelled)

# ──────────────────────────────────────────────
# 公开 API
# ──────────────────────────────────────────────

# Opens one capture session with an explicit mouse-input policy.
func open_for(action: String, display_name: String = "", allow_mouse_buttons: bool = true) -> void:
	_current_action = action
	_current_display_name = display_name if not display_name.is_empty() else action
	_allow_mouse_buttons = allow_mouse_buttons
	_waiting = true
	var accepted_inputs := "键盘、鼠标或手柄" if _allow_mouse_buttons else "键盘或手柄"
	_label.text = "%s\n按下新的%s输入" % [_current_display_name, accepted_inputs]
	popup_centered()

# ──────────────────────────────────────────────
# 输入捕获
# ──────────────────────────────────────────────

# Captures one accepted input event while the dialog is visible.
func _input(event: InputEvent) -> void:
	if not _waiting or not visible:
		return

	var accepted := false

	if event is InputEventKey and event.pressed and not event.is_echo():
		# 忽略纯修饰键（Ctrl / Shift / Alt / Meta 单独按下时不触发）
		var kc: int = event.keycode
		if kc not in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META,
					  KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]:
			accepted = true

	elif _allow_mouse_buttons and event is InputEventMouseButton and event.pressed:
		accepted = true

	elif event is InputEventJoypadButton and event.pressed:
		accepted = true

	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		accepted = true

	if accepted:
		get_viewport().set_input_as_handled()
		_waiting = false
		hide()
		key_captured.emit(event, _current_action)

# ──────────────────────────────────────────────
# 内部
# ──────────────────────────────────────────────

# Cancels the active capture request.
func _on_cancelled() -> void:
	if not _waiting:
		return
	_waiting = false
	hide()
	capture_cancelled.emit(_current_action)
