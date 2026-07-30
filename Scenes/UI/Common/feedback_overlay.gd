extends CanvasLayer

signal result_selected(confirmed: bool)

@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_title: Label = %ToastTitle
@onready var toast_text: Label = %ToastText
@onready var dialog_backdrop: SceneManagerBackdrop = %DialogBackdrop
@onready var dialog_panel: PanelContainer = %DialogPanel
@onready var dialog_title: Label = %DialogTitle
@onready var dialog_text: Label = %DialogText
@onready var confirm_button: ShaderButton = %ConfirmButton
@onready var cancel_button: ShaderButton = %CancelButton

var _toast_tween: Tween
var _dialog_open: bool
var _dialog_has_cancel: bool


# Configures shared button sounds for the authored overlay controls.
func _ready() -> void:
	GameAudio.setup_ingame_shader_button(confirm_button)
	GameAudio.setup_ingame_shader_button(cancel_button)
	GameAudio.setup_plain_button(cancel_button, "cancel")
	confirm_button.pressed.connect(_resolve_confirm)
	cancel_button.pressed.connect(_resolve_cancel)


# Shows one top-right message and replaces any existing toast.
func toast(seconds: float, title: String, text: String) -> void:
	toast_title.text = title
	toast_text.text = text
	toast_panel.show()
	toast_panel.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween().set_ignore_time_scale(true)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.18)
	_toast_tween.tween_callback(toast_panel.hide)


# Opens a blocking single-confirmation dialog for dialogue and scripted flows.
func popup_confirm(title: String, text: String) -> void:
	_open_dialog(title, text, tr("COMMON_CONFIRM"), "", false)
	await result_selected


# Opens a blocking confirmation dialog and returns the selected result.
func ask(title: String, text: String, confirm_text := tr("COMMON_CONFIRM"), cancel_text := tr("COMMON_CANCEL")) -> bool:
	_open_dialog(title, text, confirm_text, cancel_text, true)
	return await result_selected


# Populates and displays the authored dialog controls.
func _open_dialog(title: String, text: String, confirm_text: String, cancel_text: String, has_cancel: bool) -> void:
	dialog_title.text = title
	dialog_text.text = text
	confirm_button.set_bbtext(confirm_text)
	cancel_button.set_bbtext(cancel_text)
	cancel_button.visible = has_cancel
	_dialog_has_cancel = has_cancel
	_dialog_open = true
	dialog_backdrop.open_modal()
	confirm_button.grab_focus()


# Resolves an accepted dialog result.
func _resolve_confirm() -> void:
	_close_dialog(true)


# Resolves a rejected dialog result when the dialog offers cancellation.
func _resolve_cancel() -> void:
	if _dialog_has_cancel:
		_close_dialog(false)


# Closes the current dialog and emits its awaited result after the fade.
func _close_dialog(confirmed: bool) -> void:
	if not _dialog_open:
		return
	_dialog_open = false
	var tween := dialog_backdrop.close_modal()
	if tween != null:
		await tween.finished
	result_selected.emit(confirmed)
